import Foundation

/// Replaces ClaudeAPIService — all requests go through our Vercel backend.
/// The Anthropic API key lives on the server; the iOS app never sees it.
actor BackendAPIService {
    static let shared = BackendAPIService()

    private let baseURL = "https://awaken-gamma.vercel.app"

    // MARK: - Token storage

    nonisolated var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "awaken_jwt") }
    }

    nonisolated func setAccessToken(_ token: String?) {
        UserDefaults.standard.set(token, forKey: "awaken_jwt")
    }

    // MARK: - Message types (same structure as ClaudeAPIService for easy migration)

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    struct ChatResponseBody: Codable {
        let reply: String
        let daily_count: Int
        let daily_limit: Int
    }

    // MARK: - Public API

    /// Director reply (equivalent to ClaudeAPIService.sendMessage)
    func sendMessage(
        userMessage: String,
        conversationHistory: [ChatMessage],
        systemPrompt: String
    ) async throws -> String {
        var messages = conversationHistory
        messages.append(ChatMessage(role: "user", content: userMessage))
        let body = ChatResponseBody.self
        let result: ChatResponseBody = try await post(
            path: "/chat",
            payload: [
                "system_prompt": systemPrompt,
                "messages": messages.map { ["role": $0.role, "content": $0.content] },
                "max_tokens": 4096
            ]
        )
        return result.reply
    }

    /// Analysis / lightweight call (equivalent to ClaudeAPIService.sendAnalysisMessage)
    func sendAnalysisMessage(
        userMessage: String,
        systemPrompt: String,
        maxTokens: Int = 512
    ) async throws -> String {
        let result: ChatResponseBody = try await post(
            path: "/chat",
            payload: [
                "system_prompt": systemPrompt,
                "messages": [["role": "user", "content": userMessage]],
                "max_tokens": maxTokens
            ]
        )
        return result.reply
    }

    // MARK: - Private networking

    private func post<T: Decodable>(path: String, payload: [String: Any]) async throws -> T {
        guard let token = accessToken else {
            throw BackendError.notAuthenticated
        }
        guard let url = URL(string: baseURL + path) else {
            throw BackendError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw BackendError.notAuthenticated
        case 402:
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("trial_expired") {
                throw BackendError.trialExpired
            } else {
                throw BackendError.dailyLimitReached
            }
        default:
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BackendError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    // MARK: - Errors

    enum BackendError: LocalizedError {
        case notAuthenticated
        case trialExpired
        case dailyLimitReached
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:   return "請先登入"
            case .trialExpired:       return "試用期已結束"
            case .dailyLimitReached:  return "今日對話次數已達上限"
            case .invalidURL:         return "伺服器網址錯誤"
            case .invalidResponse:    return "伺服器回應無效"
            case .httpError(let code, let body):
                return "錯誤 \(code): \(body)"
            }
        }
    }
}
