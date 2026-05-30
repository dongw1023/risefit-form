import AuthenticationServices
import Foundation
import UIKit

final class WebAuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first

        guard let window else {
            fatalError("No window available for authentication.")
        }
        return window
    }
}

final class AppleAuthHandler: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let api: AuthAPI
    private let completion: (Result<String, Error>) -> Void

    init(api: AuthAPI, completion: @escaping (Result<String, Error>) -> Void) {
        self.api = api
        self.completion = completion
    }

    func start() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(AuthAPIError.message("Invalid Apple credential.")))
            return
        }

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCodeData = credential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8)
        else {
            completion(.failure(AuthAPIError.message("Apple did not return the required login tokens.")))
            return
        }

        let name = formattedName(from: credential.fullName)
        let email = credential.email

        Task {
            do {
                let token = try await api.appleLogin(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    name: name,
                    email: email
                )
                await MainActor.run {
                    completion(.success(token))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
            completion(.failure(error))
        }
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first

        guard let window else {
            fatalError("No window available for Apple authentication.")
        }
        return window
    }

    private func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = [components.givenName, components.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
