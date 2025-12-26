import Foundation
import Security

/// GitHub OAuth authentication using Device Flow
/// Device Flow is ideal for desktop apps - no redirect URL needed
@Observable
@MainActor
final class GitHubAuth {
    // MARK: - Configuration

    /// Create your own OAuth App at: https://github.com/settings/developers
    /// Set it as a "GitHub App" or "OAuth App" with Device Flow enabled
    /// Replace this with your Client ID
    private let clientID = "Ov23liorQaON8hyfOdGb"

    // MARK: - State

    private(set) var isAuthenticated: Bool = false
    private(set) var isAuthenticating: Bool = false
    private(set) var isRestoringSession: Bool = false
    private(set) var username: String?
    private(set) var avatarURL: URL?
    private(set) var userCode: String?
    private(set) var verificationURL: String?
    private(set) var errorMessage: String?

    private var accessToken: String?
    private var deviceCode: String?
    private var pollingInterval: Int = 5
    private var pollingTask: Task<Void, Never>?

    // MARK: - Keychain Keys (static to avoid actor isolation issues)

    private static let tokenKeychainKey = "com.manifest.github.token"
    private static let usernameKeychainKey = "com.manifest.github.username"

    // MARK: - Initialization

    init() {
        // Don't load token here - it will be done asynchronously via restoreSession()
    }

    // MARK: - Session Restoration

    /// Call this after app is ready to restore saved session (async, won't block)
    func restoreSession() {
        guard !isRestoringSession && !isAuthenticated else { return }
        isRestoringSession = true

        // Use Task to properly handle actor isolation
        Task.detached(priority: .utility) { [weak self] in
            // Access static keys (no actor isolation needed)
            let tokenData = Self.loadFromKeychainStatic(key: Self.tokenKeychainKey)
            let usernameData = Self.loadFromKeychainStatic(key: Self.usernameKeychainKey)

            // Update on MainActor
            await MainActor.run {
                guard let self = self else { return }
                self.isRestoringSession = false

                if let tokenData = tokenData,
                   let token = String(data: tokenData, encoding: .utf8) {
                    self.accessToken = token
                    self.isAuthenticated = true

                    if let usernameData = usernameData,
                       let savedUsername = String(data: usernameData, encoding: .utf8) {
                        self.username = savedUsername
                    }
                }
            }
        }
    }

    // MARK: - Static Keychain Access (no actor isolation)

    private static func loadFromKeychainStatic(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Public Methods

    /// Starts the Device Flow authentication process
    func startAuthentication() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        userCode = nil
        verificationURL = nil

        do {
            // Step 1: Request device and user codes
            let codeResponse = try await requestDeviceCode()
            deviceCode = codeResponse.deviceCode
            userCode = codeResponse.userCode
            verificationURL = codeResponse.verificationURI
            pollingInterval = codeResponse.interval

            // Step 2: Start polling for token (user will enter code on GitHub)
            pollingTask = Task {
                await pollForToken()
            }
        } catch {
            errorMessage = "Failed to start authentication: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }

    /// Cancels ongoing authentication
    func cancelAuthentication() {
        pollingTask?.cancel()
        pollingTask = nil
        isAuthenticating = false
        userCode = nil
        verificationURL = nil
        deviceCode = nil
    }

    /// Signs out and clears stored credentials
    func signOut() {
        accessToken = nil
        username = nil
        avatarURL = nil
        isAuthenticated = false

        // Delete from keychain on background task
        Task.detached(priority: .utility) {
            Self.deleteFromKeychainStatic(key: Self.tokenKeychainKey)
            Self.deleteFromKeychainStatic(key: Self.usernameKeychainKey)
        }
    }

    /// Makes an authenticated request to the GitHub API
    func authenticatedRequest(to endpoint: String) async throws -> Data {
        guard let token = accessToken else {
            throw GitHubAuthError.notAuthenticated
        }

        let urlString = endpoint.hasPrefix("https://")
            ? endpoint
            : "https://api.github.com\(endpoint)"

        guard let url = URL(string: urlString) else {
            throw GitHubAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Token expired or revoked
            signOut()
            throw GitHubAuthError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw GitHubAuthError.apiError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    /// Gets the current access token (for direct API use)
    var token: String? { accessToken }

    // MARK: - Device Flow Implementation

    private struct DeviceCodeResponse: Codable {
        let deviceCode: String
        let userCode: String
        let verificationURI: String
        let expiresIn: Int
        let interval: Int

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationURI = "verification_uri"
            case expiresIn = "expires_in"
            case interval
        }
    }

    private func requestDeviceCode() async throws -> DeviceCodeResponse {
        let url = URL(string: "https://github.com/login/device/code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientID)&scope=repo,read:user"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    private func pollForToken() async {
        guard let deviceCode = deviceCode else { return }

        while !Task.isCancelled {
            // Wait for the polling interval
            try? await Task.sleep(for: .seconds(pollingInterval))

            if Task.isCancelled { break }

            do {
                let token = try await requestAccessToken(deviceCode: deviceCode)
                accessToken = token

                // Fetch user info
                await fetchUserInfo()

                // Save to keychain on background queue
                saveTokenAsync(token)

                isAuthenticated = true
                isAuthenticating = false
                userCode = nil
                verificationURL = nil
                return

            } catch GitHubAuthError.authorizationPending {
                // User hasn't entered the code yet, keep polling
                continue
            } catch GitHubAuthError.slowDown {
                // GitHub wants us to slow down
                pollingInterval += 5
                continue
            } catch GitHubAuthError.expiredToken {
                errorMessage = "Authentication timed out. Please try again."
                isAuthenticating = false
                return
            } catch GitHubAuthError.accessDenied {
                errorMessage = "Access was denied."
                isAuthenticating = false
                return
            } catch {
                errorMessage = "Authentication failed: \(error.localizedDescription)"
                isAuthenticating = false
                return
            }
        }
    }

    private func requestAccessToken(deviceCode: String) async throws -> String {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct TokenResponse: Codable {
            let accessToken: String?
            let error: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case error
            }
        }

        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        if let error = response.error {
            switch error {
            case "authorization_pending":
                throw GitHubAuthError.authorizationPending
            case "slow_down":
                throw GitHubAuthError.slowDown
            case "expired_token":
                throw GitHubAuthError.expiredToken
            case "access_denied":
                throw GitHubAuthError.accessDenied
            default:
                throw GitHubAuthError.unknown(error)
            }
        }

        guard let token = response.accessToken else {
            throw GitHubAuthError.noToken
        }

        return token
    }

    private func fetchUserInfo() async {
        do {
            let data = try await authenticatedRequest(to: "/user")

            struct UserResponse: Codable {
                let login: String
                let avatarUrl: String

                enum CodingKeys: String, CodingKey {
                    case login
                    case avatarUrl = "avatar_url"
                }
            }

            let user = try JSONDecoder().decode(UserResponse.self, from: data)
            username = user.login
            avatarURL = URL(string: user.avatarUrl)

            // Save username on background task
            saveUsernameAsync(user.login)
        } catch {
            print("Failed to fetch user info: \(error)")
        }
    }

    // MARK: - Async Keychain Wrappers

    private func saveTokenAsync(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        Task.detached(priority: .utility) {
            Self.saveToKeychainStatic(data: data, key: Self.tokenKeychainKey)
        }
    }

    private func saveUsernameAsync(_ username: String) {
        guard let data = username.data(using: .utf8) else { return }
        Task.detached(priority: .utility) {
            Self.saveToKeychainStatic(data: data, key: Self.usernameKeychainKey)
        }
    }

    // MARK: - Static Keychain Operations (no actor isolation)

    private static func saveToKeychainStatic(data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteFromKeychainStatic(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Call this after app is fully launched to refresh user info
    func refreshUserInfoIfNeeded() {
        guard isAuthenticated, username == nil else { return }
        Task {
            await fetchUserInfo()
        }
    }
}

// MARK: - Errors

enum GitHubAuthError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case tokenExpired
    case authorizationPending
    case slowDown
    case expiredToken
    case accessDenied
    case noToken
    case apiError(statusCode: Int)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to GitHub"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .tokenExpired:
            return "GitHub token expired. Please sign in again."
        case .authorizationPending:
            return "Waiting for authorization"
        case .slowDown:
            return "Rate limited, slowing down"
        case .expiredToken:
            return "Device code expired"
        case .accessDenied:
            return "Access denied"
        case .noToken:
            return "No token received"
        case .apiError(let code):
            return "GitHub API error (HTTP \(code))"
        case .unknown(let msg):
            return "Unknown error: \(msg)"
        }
    }
}
