import Foundation

struct UserProfile: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        picture = try container.decodeIfPresent(String.self, forKey: .picture)
        isSubscribed = try container.decode(Bool.self, forKey: .isSubscribed)
        tier = try container.decode(String.self, forKey: .tier)
        scopes = try container.decodeIfPresent([String].self, forKey: .scopes) ?? []
    }

    let id: Int
    let email: String
    let name: String?
    let picture: String?
    let isSubscribed: Bool
    let tier: String
    let scopes: [String]

    var canRunFormCheck: Bool {
        scopes.contains("form_check:run")
    }

    enum CodingKeys: String, CodingKey {
        case id, email, name, picture, tier, scopes
        case isSubscribed = "is_subscribed"
    }
}

struct AuthAPI {
    enum SignUpResult {
        case signedIn(String)
        case verificationRequired(String)
    }

    private let baseURL = LocalConfig.apiBaseURL

    func login(email: String, password: String) async throws -> String {
        let response: AuthResponse = try await perform(
            method: "POST",
            path: "auth/login",
            body: LoginPayload(email: email, password: password)
        )

        guard let token = response.token, !token.isEmpty else {
            throw AuthAPIError.message(response.message ?? "Login did not return a token.")
        }
        return token
    }

    func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        let response: AuthResponse = try await perform(
            method: "POST",
            path: "auth/signup",
            body: SignUpPayload(email: email, password: password, name: name)
        )

        if let token = response.token, !token.isEmpty {
            return .signedIn(token)
        }

        return .verificationRequired(response.message ?? "Account created. Please verify your email before logging in.")
    }

    func fetchMe(token: String) async throws -> UserProfile {
        return try await perform(
            method: "GET",
            path: "auth/me",
            authToken: token
        )
    }

    func deleteAccount(token: String) async throws {
        let _: AuthResponse = try await perform(
            method: "DELETE",
            path: "auth/profile",
            authToken: token
        )
    }

    func appleLogin(identityToken: String, authorizationCode: String, name: String?, email: String?) async throws -> String {
        let response: AuthResponse = try await perform(
            method: "POST",
            path: "auth/apple/native",
            body: AppleLoginPayload(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: name,
                email: email
            )
        )

        guard let token = response.token, !token.isEmpty else {
            throw AuthAPIError.message(response.message ?? "Apple login did not return a token.")
        }
        return token
    }

    private func perform<ResponseBody: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil,
        authToken: String? = nil
    ) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthAPIError.message("Invalid server response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(AuthResponse.self, from: data)
            let message = errorResponse?.error ?? errorResponse?.message ?? "Request failed (status: \(httpResponse.statusCode))."
            throw AuthAPIError.message(message)
        }

        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
}

private struct LoginPayload: Encodable {
    let email: String
    let password: String
}

private struct SignUpPayload: Encodable {
    let email: String
    let password: String
    let name: String
}

private struct AppleLoginPayload: Encodable {
    let identityToken: String
    let authorizationCode: String
    let fullName: String?
    let email: String?
}

private struct AuthResponse: Decodable {
    let token: String?
    let message: String?
    let error: String?
}

enum AuthAPIError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}
