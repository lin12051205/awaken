import Foundation
import AuthenticationServices
import CryptoKit

// Firebase imports — added after you add Firebase SDK in Xcode
import FirebaseAuth
import FirebaseCore

@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var plan: String = "trial"
    @Published var dailyCount: Int = 0
    @Published var dailyLimit: Int = 12
    @Published var isTrialExpired: Bool = false

    private let backendURL = "https://awaken-gamma.vercel.app"
    private var currentNonce: String?

    override init() {
        super.init()
        isSignedIn = BackendAPIService.shared.accessToken != nil
        // Restore cached user status
        plan = UserDefaults.standard.string(forKey: "awaken_plan") ?? "trial"
        dailyCount = UserDefaults.standard.integer(forKey: "awaken_daily_count")
        dailyLimit = UserDefaults.standard.integer(forKey: "awaken_daily_limit").nonZero ?? 12
        isTrialExpired = UserDefaults.standard.bool(forKey: "awaken_trial_expired")
    }

    // MARK: - Sign In with Apple

    func signInWithApple() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let nonce = randomNonceString()
            currentNonce = nonce

            // Step 1: Apple credential
            let appleCredential = try await requestAppleCredential(nonce: nonce)

            // Step 2: Firebase sign-in
            guard let idTokenData = appleCredential.identityToken,
                  let idTokenString = String(data: idTokenData, encoding: .utf8) else {
                throw AuthError.missingToken
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )
            let authResult = try await Auth.auth().signIn(with: firebaseCredential)

            // Step 3: Get Firebase ID token
            let firebaseToken = try await authResult.user.getIDToken()

            // Step 4: Exchange with our backend
            let fullName = [appleCredential.fullName?.givenName, appleCredential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")

            try await exchangeWithBackend(firebaseToken: firebaseToken, fullName: fullName.isEmpty ? nil : fullName)

        } catch {
            print("Sign in error: \(error)")
            lastError = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
        BackendAPIService.shared.setAccessToken(nil)
        UserDefaults.standard.removeObject(forKey: "awaken_plan")
        UserDefaults.standard.removeObject(forKey: "awaken_daily_count")
        UserDefaults.standard.removeObject(forKey: "awaken_daily_limit")
        UserDefaults.standard.removeObject(forKey: "awaken_trial_expired")
        isSignedIn = false
        plan = "trial"
        dailyCount = 0
        dailyLimit = 12
        isTrialExpired = false
    }

    // MARK: - Refresh user status from backend

    func refreshStatus() async {
        guard let token = BackendAPIService.shared.accessToken,
              let url = URL(string: "\(backendURL)/user/status") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let status = try? JSONDecoder().decode(UserStatus.self, from: data) else { return }

        applyStatus(status)
    }

    func recordConversation() {
        dailyCount = min(dailyCount + 1, dailyLimit)
        UserDefaults.standard.set(dailyCount, forKey: "awaken_daily_count")
    }

    // MARK: - Private helpers

    private func exchangeWithBackend(firebaseToken: String, fullName: String?) async throws {
        guard let url = URL(string: "\(backendURL)/auth/firebase") else { return }

        var body: [String: Any] = ["firebase_id_token": firebaseToken]
        if let name = fullName { body["full_name"] = name }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("Backend auth failed \(statusCode): \(body)")
            throw NSError(domain: "AuthService", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "後端錯誤 \(statusCode): \(body)"])
        }

        let authResp = try JSONDecoder().decode(AuthResponse.self, from: data)
        BackendAPIService.shared.setAccessToken(authResp.access_token)
        applyStatus(UserStatus(
            user_id: authResp.user_id,
            plan: authResp.plan,
            trial_started_at: authResp.trial_started_at,
            daily_count: authResp.daily_count,
            daily_limit: authResp.daily_limit,
            is_trial_expired: authResp.is_trial_expired,
            total_conversations: 0
        ))
        isSignedIn = true
    }

    private func applyStatus(_ status: UserStatus) {
        plan = status.plan
        dailyCount = status.daily_count
        dailyLimit = status.daily_limit
        isTrialExpired = status.is_trial_expired
        UserDefaults.standard.set(plan, forKey: "awaken_plan")
        UserDefaults.standard.set(dailyCount, forKey: "awaken_daily_count")
        UserDefaults.standard.set(dailyLimit, forKey: "awaken_daily_limit")
        UserDefaults.standard.set(isTrialExpired, forKey: "awaken_trial_expired")
    }

    // MARK: - Apple credential (async wrapper)

    private func requestAppleCredential(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            // Keep delegate alive during the async call
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Response models

    struct AuthResponse: Codable {
        let access_token: String
        let user_id: String
        let plan: String
        let trial_started_at: String?
        let daily_count: Int
        let daily_limit: Int
        let is_trial_expired: Bool
    }

    struct UserStatus: Codable {
        let user_id: String
        let plan: String
        let trial_started_at: String?
        let daily_count: Int
        let daily_limit: Int
        let is_trial_expired: Bool
        let total_conversations: Int
    }

    enum AuthError: LocalizedError {
        case missingToken
        case backendError
        var errorDescription: String? {
            switch self {
            case .missingToken: return "無法取得登入憑證"
            case .backendError: return "伺服器登入失敗，請稍後再試"
            }
        }
    }
}

// MARK: - Apple Sign-In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: AuthService.AuthError.missingToken)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Int helper

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
