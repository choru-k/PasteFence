import Foundation

/// Client for communicating with local Ollama server
actor OllamaClient {
    private let baseURL: URL
    private let session: URLSession

    init(host: String = "localhost", port: Int = 11434) {
        self.baseURL = URL(string: "http://\(host):\(port)")!
        self.session = URLSession.shared
    }

    // MARK: - API Methods

    /// Check if Ollama server is running
    func isAvailable() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")

        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// List available models
    func listModels() async throws -> [OllamaModel] {
        let url = baseURL.appendingPathComponent("api/tags")
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return response.models
    }

    /// Generate text completion
    func generate(
        model: String,
        prompt: String,
        options: GenerateOptions = .default
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")

        let request = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: options
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 60

        let (data, _) = try await session.data(for: urlRequest)
        let response = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

        return response.response
    }

    /// Generate with streaming
    func generateStream(
        model: String,
        prompt: String,
        options: GenerateOptions = .default
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appendingPathComponent("api/generate")

                    let request = OllamaGenerateRequest(
                        model: model,
                        prompt: prompt,
                        stream: true,
                        options: options
                    )

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, _) = try await session.bytes(for: urlRequest)

                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
                        continuation.yield(chunk.response)

                        if chunk.done {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Request/Response Models

struct GenerateOptions: Codable {
    let temperature: Double
    let topP: Double
    let topK: Int
    let numPredict: Int

    static let `default` = GenerateOptions(
        temperature: 0.7,
        topP: 0.8,
        topK: 20,
        numPredict: 512
    )

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case numPredict = "num_predict"
    }
}

private struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: GenerateOptions
}

private struct OllamaGenerateResponse: Codable {
    let response: String
    let done: Bool
    let totalDuration: Int?
    let loadDuration: Int?
    let evalCount: Int?
    let evalDuration: Int?

    enum CodingKeys: String, CodingKey {
        case response, done
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

private struct OllamaStreamChunk: Codable {
    let response: String
    let done: Bool
}

private struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable, Identifiable {
    let name: String
    let modifiedAt: String?
    let size: Int?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
    }
}
