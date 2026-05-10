import Foundation

actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let modelMain = "claude-sonnet-4-20250514"
    private let modelLight = "claude-haiku-4-20250414"

    struct APIMessage: Codable {
        let role: String
        let content: String
    }

    struct APIRequest: Codable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [APIMessage]
    }

    struct APIResponse: Codable {
        let content: [ContentBlock]

        struct ContentBlock: Codable {
            let type: String
            let text: String?
        }
    }

    func sendMessage(
        userMessage: String,
        conversationHistory: [APIMessage],
        systemPrompt: String,
        apiKey: String
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        var messages = conversationHistory
        messages.append(APIMessage(role: "user", content: userMessage))

        let request = APIRequest(
            model: modelMain,
            max_tokens: 4096,
            system: systemPrompt,
            messages: messages
        )

        return try await executeRequest(request, apiKey: apiKey)
    }

    /// Lightweight API call for structured JSON responses — uses Haiku (much cheaper)
    func sendAnalysisMessage(
        userMessage: String,
        systemPrompt: String,
        apiKey: String,
        maxTokens: Int = 512
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        let request = APIRequest(
            model: modelLight,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: [APIMessage(role: "user", content: userMessage)]
        )

        return try await executeRequest(request, apiKey: apiKey)
    }

    private func executeRequest(_ request: APIRequest, apiKey: String) async throws -> String {
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let text = apiResponse.content.first?.text else {
            throw APIError.emptyResponse
        }

        return text
    }

    enum APIError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case httpError(statusCode: Int, body: String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "請先在設定中輸入 API Key"
            case .invalidResponse:
                return "伺服器回應無效"
            case .httpError(let code, let body):
                return "HTTP 錯誤 \(code): \(body)"
            case .emptyResponse:
                return "AI 回應為空"
            }
        }
    }
}
