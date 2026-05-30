import Foundation

struct AuthAPI {
    enum SignUpResult {
        case signedIn(String)
        case verificationRequired(String)
    }

    private let baseURL = LocalConfig.apiBaseURL

    func login(email: String, password: String) async throws -> String {
        let response: AuthResponse = try await post(
            path: "auth/login",
            body: LoginPayload(email: email, password: password)
        )

        guard let token = response.token, !token.isEmpty else {
            throw AuthAPIError.message(response.message ?? "Login did not return a token.")
        }
        return token
    }

    func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        let response: AuthResponse = try await post(
            path: "auth/signup",
            body: SignUpPayload(email: email, password: password, name: name)
        )

        if let token = response.token, !token.isEmpty {
            return .signedIn(token)
        }

        return .verificationRequired(response.message ?? "Account created. Please verify your email before logging in.")
    }

    func appleLogin(identityToken: String, authorizationCode: String, name: String?, email: String?) async throws -> String {
        let response: AuthResponse = try await post(
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

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthAPIError.message("Invalid server response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(AuthResponse.self, from: data)
            let message = errorResponse?.error ?? errorResponse?.message ?? "Request failed."
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
