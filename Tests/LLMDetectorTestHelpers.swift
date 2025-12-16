import XCTest
@testable import PasteFence

// MARK: - Testable Response Models
// Same structure as private types in LLMDetector for testing JSON decoding

struct LLMResponseTestable: Codable {
    let detected: [LLMDetectedItemTestable]
}

struct LLMDetectedItemTestable: Codable {
    let text: String
    let type: String
    let confidence: Double?  // Optional - LLM may omit this field
}

// MARK: - LLMDetector Test Helper
// Mirrors LLMDetector's private parsing logic for unit testing without LLM

struct LLMDetectorTestHelper {

    // MARK: - Strip Think Block

    /// Strip think block and extract clean content
    /// Handles: <think>...</think>, unclosed <think>, and markdown code blocks
    static func stripThinkBlock(from text: String) -> String {
        var result = text

        // Case 1: Proper <think>...</think> tags
        if let thinkEnd = text.range(of: "</think>") {
            result = String(text[thinkEnd.upperBound...])
        }
        // Case 2: Unclosed <think> - try to extract from code block or after special tokens
        else if text.contains("<think>") {
            // Try to extract JSON from markdown code block first
            if let codeBlockJson = extractFromCodeBlock(text) {
                return codeBlockJson
            }
            // Try to find content after <|endoftext|>
            if let endOfText = text.range(of: "<|endoftext|>") {
                result = String(text[endOfText.upperBound...])
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Extract From Code Block

    /// Extract JSON from markdown code block ```json...```
    static func extractFromCodeBlock(_ text: String) -> String? {
        // Look for ```json or ``` followed by JSON
        let patterns = ["```json\\s*\\n([\\s\\S]*?)```", "```\\s*\\n(\\{[\\s\\S]*?\\})\\s*```"]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                return extracted
            }
        }
        return nil
    }

    // MARK: - Normalize Type Case

    /// Normalize type string from camelCase to UPPER_SNAKE_CASE
    /// e.g., "privateKey" → "PRIVATE_KEY", "ipAddress" → "IP_ADDRESS"
    static func normalizeTypeCase(_ input: String) -> String {
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

    // MARK: - Find Matching Bracket

    /// Find matching closing bracket for array starting at position 0
    static func findMatchingBracket(in text: String) -> String.Index? {
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

    // MARK: - Extract First JSON Object

    /// Extract the first complete JSON object from a string by matching braces
    /// Handles nested objects and strings containing braces
    static func extractFirstJSONObject(from text: String) -> String? {
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

    // MARK: - Build Prompt

    /// System prompt with schema and rules (matches LLMDetector)
    static let systemPrompt = """
        You are a strict PII detector. Output ONLY valid JSON.

        Schema: {"detected": [{"text": string, "type": "PASSWORD"|"API_KEY"|"SECRET"|"EMAIL"|"PHONE"|"IP_ADDRESS"|"CREDIT_CARD"|"PRIVATE_KEY"|"JWT"|"AWS_KEY"}]}

        Rules:
        1. Extract text EXACTLY as it appears between INPUT_START and INPUT_END.
        2. Prioritize: PASSWORD, API_KEY, SECRET (others handled by regex).
        3. If nothing found, output ]}
        4. NO markdown. NO explanations. JSON only.
        5. Do NOT invent data. Only output text that exists in the input.
        """

    /// JSON prefix that is pre-filled in the prompt
    static let jsonPrefix = "{\"detected\": ["

    /// Format prompt using Qwen3 chat template with pre-filled JSON start
    static func formatForQwen3(system: String, user: String) -> String {
        """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant
        {"detected": [
        """
    }

    /// Create user prompt with text to analyze (zero-shot with INPUT markers)
    static func createUserPrompt(for text: String) -> String {
        """
        INPUT_START
        \(text)
        INPUT_END

        Analyze text. Return JSON now.
        """
    }

    static func buildPrompt(for text: String) -> String {
        formatForQwen3(system: systemPrompt, user: createUserPrompt(for: text))
    }

    // MARK: - Token Estimation

    /// Mirror of LLMDetector's token estimation logic
    static func estimateTokens(_ text: String) -> Int {
        return max(1, text.count / 4)
    }

    // MARK: - Chunking Constants (mirrors LLMDetector)

    /// Maximum characters per chunk (~20K tokens)
    static let chunkSize = 80_000
    /// Overlap between chunks (~2.5K tokens)
    static let chunkOverlap = 10_000

    // MARK: - Chunking Logic (mirrors LLMDetector)

    /// Splits large text into overlapping chunks for processing
    /// - Parameter text: Original text to split
    /// - Returns: Array of (chunkText, startOffset) tuples
    static func splitIntoChunks(_ text: String) -> [(text: String, offset: Int)] {
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

    // MARK: - Truncation Detection (mirrors LLMDetector)

    /// Checks if LLM response appears truncated (incomplete JSON)
    /// Used to detect when output exceeds max tokens and gets cut off
    /// - Parameter response: The raw or cleaned LLM response string
    /// - Returns: true if response appears incomplete/truncated
    static func isTruncated(_ response: String) -> Bool {
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

    // MARK: - Deduplication (mirrors LLMDetector)

    /// Removes duplicate detections from overlap regions
    /// Priority: higher confidence > longer match (if confidence equal)
    static func deduplicateResults(_ items: [DetectedItem]) -> [DetectedItem] {
        guard items.count > 1 else { return items }

        // Sort by position in text
        let sorted = items.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var result: [DetectedItem] = []

        for item in sorted {
            if let last = result.last, last.range.overlaps(item.range) {
                // Overlapping detection - keep the better one
                if item.confidence > last.confidence ||
                   (item.confidence == last.confidence && item.text.count > last.text.count) {
                    result.removeLast()
                    result.append(item)
                }
            } else {
                result.append(item)
            }
        }

        return result
    }
}
