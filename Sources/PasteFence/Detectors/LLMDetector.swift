import Foundation

/// LLM-based detector for context-aware sensitive data detection
/// Uses local MLX model for inference with Qwen3 chat format
actor LLMDetector {
    private let llmEngine: LLMEngine

    // MARK: - Token Budget Constants

    /// Safety factor for context usage (80% of max)
    private let contextSafetyFactor: Double = 0.8
    /// Minimum tokens reserved for output (for valid JSON response)
    private let minOutputTokens: Int = 64
    /// Maximum tokens for output (parser handles extracting JSON from any trailing garbage)
    private let maxOutputTokens: Int = 1024

    // MARK: - Chunking Constants

    /// Maximum characters per chunk (~20K tokens, well under 25K safe limit)
    private let chunkSize = 80_000
    /// Overlap between chunks (~2.5K tokens, catches boundary PII)
    private let chunkOverlap = 10_000

    // MARK: - Cached Prompt Data

    /// Cached valid types schema (snapshot at init time)
    private let cachedTypesSchema: String
    /// Cached pattern instructions (snapshot at init time)
    private let cachedPatternInstructions: String

    /// System prompt built from cached data
    private var systemPrompt: String {
        """
        You are a strict PII detector. Output ONLY valid JSON.

        Schema: {"detected": [{"text": string, "type": \(cachedTypesSchema)}]}

        \(cachedPatternInstructions)

        Rules:
        1. Extract text EXACTLY as it appears between INPUT_START and INPUT_END.
        2. Prioritize: PASSWORD, API_KEY, SECRET, PRIVATE_KEY (others handled by regex).
        3. If nothing found, output ]}
        4. NO markdown. NO explanations. JSON only.
        5. Do NOT invent data. Only output text that exists in the input.
        """
    }

    @MainActor
    init(modelPath: String, promptRulesManager: PromptRulesManager = PromptRulesManager.shared) async throws {
        // Cache prompt rules data at init time (on main actor)
        let allTypes = promptRulesManager.enabledRules.map { $0.sensitiveType }
        self.cachedTypesSchema = allTypes.map { "\"\($0)\"" }.joined(separator: "|")
        self.cachedPatternInstructions = promptRulesManager.buildPromptInstructions() ?? ""

        self.llmEngine = try await LLMEngine(modelPath: modelPath)
    }

    // MARK: - Token Estimation

    /// Estimate token count (rough: ~4 chars per token for English text)
    private func estimateTokens(_ text: String) -> Int {
        return max(1, text.count / 4)
    }

    /// Detect sensitive information using LLM
    /// Automatically routes to chunked processing for large inputs
    func detect(in text: String) async throws -> [DetectedItem] {
        // Calculate max input size based on context length
        let contextLength = await llmEngine.contextLength
        let safeLimit = Int(Double(contextLength) * contextSafetyFactor)
        let maxAllowedPromptTokens = safeLimit - minOutputTokens

        // Estimate prompt overhead (system prompt + template) using empty text
        let promptOverhead = estimateTokens(buildPrompt(for: ""))
        let maxInputTokens = maxAllowedPromptTokens - promptOverhead
        let maxInputChars = maxInputTokens * 4  // ~4 chars per token

        // Route based on input size
        if text.count <= maxInputChars {
            // Small input - single pass processing
            return try await detectSinglePass(text)
        }

        // Large input - chunked processing
        print("[LLMDetector] Input too large (\(text.count) chars > \(maxInputChars) max), using chunking")
        return try await detectWithChunking(text)
    }

    /// Process text in a single LLM call (for inputs within token limit)
    private func detectSinglePass(_ text: String) async throws -> [DetectedItem] {
        let prompt = buildPrompt(for: text)

        // Calculate dynamic token budget
        let contextLength = await llmEngine.contextLength
        let safeLimit = Int(Double(contextLength) * contextSafetyFactor)
        let promptTokens = estimateTokens(prompt)

        // Calculate available tokens for output (clamped to reasonable range)
        let availableTokens = safeLimit - promptTokens
        let maxTokens = min(max(availableTokens, minOutputTokens), maxOutputTokens)

        print("[LLMDetector] Token budget: prompt=\(promptTokens), maxOutput=\(maxTokens), safeLimit=\(safeLimit)")
        print("[LLMDetector] === PROMPT ===")
        print(prompt)
        print("[LLMDetector] === END PROMPT ===")

        // Use temp=0.0 for deterministic extraction, topP=1.0 (irrelevant at temp=0)
        let response = try await llmEngine.generate(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: 0.0,
            topP: 1.0
        )

        print("[LLMDetector] === RAW RESPONSE ===")
        print(response)
        print("[LLMDetector] === END RESPONSE ===")

        return try parseResponse(response, originalText: text)
    }

    // MARK: - Prompt Building

    /// Format prompt using Qwen3 chat template with pre-filled JSON start
    /// This forces the model to continue from valid JSON structure
    private func formatForQwen3(system: String, user: String) -> String {
        """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant
        {"detected": [
        """
    }

    /// JSON prefix that was pre-filled in the prompt
    private let jsonPrefix = "{\"detected\": ["

    /// Create user prompt with text to analyze
    /// Zero-shot approach with clear INPUT markers (no examples to prevent hallucination)
    /// /no_think suffix disables Qwen3's thinking mode for faster, more consistent output
    private func createUserPrompt(for text: String) -> String {
        """
        INPUT_START
        \(text)
        INPUT_END

        Analyze text. Return JSON now./no_think
        """
    }

    private func buildPrompt(for text: String) -> String {
        formatForQwen3(system: systemPrompt, user: createUserPrompt(for: text))
    }

    // MARK: - Chunking

    /// Splits large text into overlapping chunks for processing
    /// - Parameter text: Original text to split
    /// - Returns: Array of (chunkText, startOffset) tuples
    private func splitIntoChunks(_ text: String) -> [(text: String, offset: Int)] {
        let stride = chunkSize - chunkOverlap

        // If text fits in single chunk, return as-is
        guard text.count > chunkSize else { return [(text, 0)] }

        var chunks: [(String, Int)] = []
        var offset = 0

        while offset < text.count {
            let startIndex = text.index(text.startIndex, offsetBy: offset)
            let endOffset = min(offset + chunkSize, text.count)
            let endIndex = text.index(text.startIndex, offsetBy: endOffset)
            chunks.append((String(text[startIndex..<endIndex]), offset))
            offset += stride
            // Break if we've reached the end
            if endOffset == text.count { break }
        }

        return chunks
    }

    /// Process large text in chunks and merge results
    /// - Parameter text: Original text (exceeds single-pass limit)
    /// - Returns: Deduplicated detected items with correct ranges
    private func detectWithChunking(_ text: String) async throws -> [DetectedItem] {
        let chunks = splitIntoChunks(text)
        var allResults: [DetectedItem] = []

        print("[LLMDetector] Processing \(chunks.count) chunks for \(text.count) char input...")

        for (index, (chunkText, _)) in chunks.enumerated() {
            print("[LLMDetector] Chunk \(index + 1)/\(chunks.count) (\(chunkText.count) chars)")

            let prompt = buildPrompt(for: chunkText)
            let response = try await llmEngine.generate(
                prompt: prompt,
                maxTokens: maxOutputTokens,
                temperature: 0.0,
                topP: 1.0
            )

            // Parse against FULL original text - automatically validates and maps ranges correctly
            let chunkResults = try parseResponse(response, originalText: text)
            allResults.append(contentsOf: chunkResults)

            print("[LLMDetector] Chunk \(index + 1) found \(chunkResults.count) items")
        }

        let deduplicated = deduplicateResults(allResults)
        print("[LLMDetector] Total: \(allResults.count) items → \(deduplicated.count) after deduplication")

        return deduplicated
    }

    /// Removes duplicate detections from overlap regions
    /// Priority: higher confidence > longer match (if confidence equal)
    /// - Parameter items: All detected items (may contain duplicates from overlapping chunks)
    /// - Returns: Deduplicated array sorted by position
    private func deduplicateResults(_ items: [DetectedItem]) -> [DetectedItem] {
        guard items.count > 1 else { return items }

        // Sort by position in text
        let sorted = items.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var result: [DetectedItem] = []

        for item in sorted {
            if let last = result.last, last.range.overlaps(item.range) {
                // Overlapping detection - keep the better one
                // Priority: higher confidence, then longer match
                if item.confidence > last.confidence ||
                   (item.confidence == last.confidence && item.text.count > last.text.count) {
                    result.removeLast()
                    result.append(item)
                }
                // else: keep existing (last) - it's better or equal
            } else {
                // No overlap - add to result
                result.append(item)
            }
        }

        return result
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: String, originalText: String) throws -> [DetectedItem] {
        // Strip any remaining think block content (in case model still outputs some)
        var cleanedResponse = stripThinkBlock(from: response)

        // Check for truncation BEFORE attempting to parse
        // This catches cases where output was cut off due to max token limit
        if isTruncated(cleanedResponse) {
            print("[LLMDetector] Response appears truncated: \(cleanedResponse.suffix(50))...")
            throw LLMDetectorError.outputTruncated
        }

        // DEFENSIVE CHECK: Only prepend if response doesn't already have complete JSON
        // If model output a complete JSON object (after think block), use it directly
        let trimmedCheck = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCheck.hasPrefix("{") {
            // Model continued from our prefix - prepend it
            cleanedResponse = jsonPrefix + cleanedResponse
            print("[LLMDetector] Prepended JSON prefix (model continued from prefix)")
        } else {
            // Model returned complete JSON - use as-is
            print("[LLMDetector] Model returned complete JSON, using as-is")
        }

        print("[LLMDetector] Full JSON: \(cleanedResponse.prefix(300))...")

        // Try to extract JSON - handle both array and object formats
        let jsonString: String
        let trimmed = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("[") {
            // LLM returned bare array - wrap in {"detected": ...}
            if let arrayEnd = findMatchingBracket(in: trimmed) {
                let arrayJson = String(trimmed[trimmed.startIndex...arrayEnd])
                jsonString = "{\"detected\": \(arrayJson)}"
                print("[LLMDetector] Wrapped bare array in object format")
            } else {
                print("[LLMDetector] Failed to parse bare array")
                return []
            }
        } else if let extracted = extractFirstJSONObject(from: cleanedResponse) {
            jsonString = extracted
        } else {
            print("[LLMDetector] No valid JSON found in response: \(cleanedResponse.prefix(100))...")
            return []
        }

        print("[LLMDetector] Extracted JSON: \(jsonString.prefix(200))...")

        guard let data = jsonString.data(using: .utf8) else {
            print("[LLMDetector] Failed to convert JSON to data")
            return []
        }

        do {
            let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
            print("[LLMDetector] Decoded \(decoded.detected.count) items from LLM response")

            return decoded.detected.compactMap { item in
                // Validate confidence is in valid range (0.0-1.0), default to 0.85 if missing
                let confidence = min(max(item.confidence ?? 0.85, 0.0), 1.0)

                // Find the range of the detected text in the original (case-sensitive)
                guard let range = originalText.range(of: item.text) else {
                    print("[LLMDetector] Hallucination: '\(item.text)' not found in original text")
                    return nil
                }

                // Infer type if LLM omitted it, otherwise normalize from camelCase
                let normalizedType: String
                if let typeString = item.type {
                    normalizedType = normalizeTypeCase(typeString)
                } else {
                    normalizedType = inferTypeFromText(item.text)
                    print("[LLMDetector] Inferred type '\(normalizedType)' for text '\(item.text)'")
                }

                // Map type string to SensitiveType enum
                guard let type = SensitiveType(rawValue: normalizedType) else {
                    print("[LLMDetector] Unknown type '\(item.type ?? "nil")' (normalized: '\(normalizedType)') for text '\(item.text)'")
                    return nil
                }

                return DetectedItem(
                    text: item.text,
                    type: type,
                    range: range,
                    confidence: confidence,
                    source: .llm,
                    ruleName: nil  // LLM detections don't have a rule name
                )
            }
        } catch {
            print("[LLMDetector] JSON parse error: \(error.localizedDescription)")
            return []
        }
    }

    /// Strip think block and extract clean content
    /// Handles: <think>...</think>, unclosed <think>, multiple </think> tags, and markdown code blocks
    private func stripThinkBlock(from text: String) -> String {
        var result = text

        // Strip ALL </think> tags (some models output multiple empty ones)
        while let thinkEnd = result.range(of: "</think>") {
            result = String(result[thinkEnd.upperBound...])
        }

        // Handle unclosed <think> - extract JSON directly from inside
        if let thinkStart = result.range(of: "<think>") {
            let afterThink = String(result[thinkStart.upperBound...])

            // Try to extract JSON from markdown code block first
            if let codeBlockJson = extractFromCodeBlock(afterThink) {
                return codeBlockJson
            }

            // Look for JSON object start directly after <think>
            if let jsonStart = afterThink.firstIndex(of: "{") {
                result = String(afterThink[jsonStart...])
                print("[LLMDetector] Extracted JSON from inside unclosed <think> block")
            } else if let endOfText = afterThink.range(of: "<|endoftext|>") {
                // Fallback: try after <|endoftext|>
                result = String(afterThink[endOfText.upperBound...])
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract JSON from markdown code block ```json...```
    private func extractFromCodeBlock(_ text: String) -> String? {
        // Look for ```json or ``` followed by JSON
        let patterns = ["```json\\s*\\n([\\s\\S]*?)```", "```\\s*\\n(\\{[\\s\\S]*?\\})\\s*```"]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                print("[LLMDetector] Extracted JSON from code block")
                return extracted
            }
        }
        return nil
    }

    /// Normalize type string from camelCase to UPPER_SNAKE_CASE
    /// e.g., "privateKey" → "PRIVATE_KEY", "ipAddress" → "IP_ADDRESS"
    private func normalizeTypeCase(_ input: String) -> String {
        // Insert underscore before uppercase letters: privateKey → private_Key
        let pattern = "([a-z0-9])([A-Z])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return input.uppercased()
        }
        let range = NSRange(location: 0, length: input.utf16.count)
        let snakeCase = regex.stringByReplacingMatches(
            in: input, range: range, withTemplate: "$1_$2"
        )
        // Convert to UPPER_SNAKE_CASE
        return snakeCase.replacingOccurrences(of: " ", with: "_").uppercased()
    }

    /// Infer type from detected text when LLM omits the type field
    private func inferTypeFromText(_ text: String) -> String {
        let lower = text.lowercased()
        // API keys
        if lower.contains("api_key") || lower.contains("apikey") || lower.hasPrefix("sk-") {
            return "API_KEY"
        }
        // Passwords
        if lower.contains("password") || lower.contains("passwd") || lower.contains("pwd") {
            return "PASSWORD"
        }
        // Private keys - check for PEM header OR base64 MII prefix (RSA/EC keys start with MII)
        if lower.contains("private") && lower.contains("key") {
            return "PRIVATE_KEY"
        }
        if text.hasPrefix("MII") || (lower.contains("begin") && lower.contains("private")) {
            return "PRIVATE_KEY"
        }
        // AWS keys
        if lower.hasPrefix("akia") || lower.contains("aws_") {
            return "AWS_KEY"
        }
        // Generic secrets (fallback)
        return "SECRET"
    }

    /// Find matching closing bracket for array starting at position 0
    private func findMatchingBracket(in text: String) -> String.Index? {
        guard text.first == "[" else { return nil }

        var bracketCount = 0
        var inString = false
        var escaped = false

        for (offset, char) in text.enumerated() {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" && inString {
                escaped = true
                continue
            }

            if char == "\"" {
                inString = !inString
                continue
            }

            if !inString {
                if char == "[" {
                    bracketCount += 1
                } else if char == "]" {
                    bracketCount -= 1
                    if bracketCount == 0 {
                        return text.index(text.startIndex, offsetBy: offset)
                    }
                }
            }
        }

        return nil
    }

    /// Extract the first complete JSON object from a string by matching braces
    /// Handles nested objects and strings containing braces
    private func extractFirstJSONObject(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{") else { return nil }

        var braceCount = 0
        var inString = false
        var escaped = false

        for (offset, char) in text[startIndex...].enumerated() {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" && inString {
                escaped = true
                continue
            }

            if char == "\"" {
                inString = !inString
                continue
            }

            if !inString {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        let endIndex = text.index(startIndex, offsetBy: offset)
                        return String(text[startIndex...endIndex])
                    }
                }
            }
        }

        return nil
    }

    /// Checks if LLM response appears truncated (incomplete JSON)
    /// Used to detect when output exceeds max tokens and gets cut off
    /// - Parameter response: The raw or cleaned LLM response string
    /// - Returns: true if response appears incomplete/truncated
    private func isTruncated(_ response: String) -> Bool {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty response is not truncated (just nothing found)
        if trimmed.isEmpty {
            return false
        }

        // Check 1: Should end with proper JSON closure (]} or just } for complete object)
        if !trimmed.hasSuffix("]}") && !trimmed.hasSuffix("}") {
            return true
        }

        // Check 2: Unbalanced brackets indicate truncation
        let openBrackets = trimmed.filter { $0 == "[" }.count
        let closeBrackets = trimmed.filter { $0 == "]" }.count
        if openBrackets > closeBrackets {
            return true
        }

        // Check 3: Unbalanced braces
        let openBraces = trimmed.filter { $0 == "{" }.count
        let closeBraces = trimmed.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            return true
        }

        return false
    }
}

// MARK: - Response Models

private struct LLMResponse: Codable {
    let detected: [LLMDetectedItem]
}

private struct LLMDetectedItem: Codable {
    let text: String
    let type: String?  // Optional - LLM sometimes omits this field
    let confidence: Double?  // Optional - LLM may omit this field
}

// MARK: - Errors

enum LLMDetectorError: LocalizedError {
    case inputTooLarge(estimatedTokens: Int, maxAllowed: Int)
    case outputTruncated

    var errorDescription: String? {
        switch self {
        case .inputTooLarge(let estimated, let max):
            return "Input too large (~\(estimated) tokens). Maximum supported: ~\(max) tokens. Please reduce input size."
        case .outputTruncated:
            return "Too many sensitive items detected. Please use smaller input."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .inputTooLarge, .outputTruncated:
            return "Try copying a smaller portion of text."
        }
    }
}
