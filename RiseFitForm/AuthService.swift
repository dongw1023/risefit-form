import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var authToken: String?

    private let tokenKey = "risefitForm.authToken"

    init() {
        let storedToken = UserDefaults.standard.string(forKey: tokenKey)
        authToken = storedToken?.isEmpty == false ? storedToken : nil
    }

    func signIn(token: String) {
        authToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    func signOut() {
        authToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
