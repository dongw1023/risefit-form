import AuthenticationServices
import SwiftUI

struct AuthView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case login = "Log In"
        case signUp = "Sign Up"

        var id: String { rawValue }
    }

    @EnvironmentObject private var authService: AuthService
    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var isSubmitting = false
    @State private var webAuthSession: ASWebAuthenticationSession?
    @State private var appleAuthHandler: AppleAuthHandler?

    private let api = AuthAPI()
    private let webAuthProvider = WebAuthenticationContextProvider()

    var body: some View {
        ZStack {
            RiseAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    brand
                    form
                }
                .padding(.horizontal, 22)
                .padding(.top, 58)
                .padding(.bottom, 28)
            }
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.riseMint.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.riseMint)
            }

            Text("RiseFit Form")
                .riseFont(.header)
                .foregroundStyle(Color.riseText)

            Text("Sign in to analyse your lifting videos with your RiseFit account.")
                .riseFont(.bodyBold)
                .foregroundStyle(Color.riseText.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 12) {
                SocialAuthButton(title: "Continue with Apple", icon: "applelogo", style: .dark) {
                    signInWithApple()
                }

                SocialAuthButton(title: "Continue with Google", icon: "g.circle.fill", style: .light) {
                    signInWithGoogle()
                }
            }

            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.riseText.opacity(0.16))
                    .frame(height: 1)
                Text("OR")
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.46))
                Rectangle()
                    .fill(Color.riseText.opacity(0.16))
                    .frame(height: 1)
            }

            Picker("Auth mode", selection: Binding(
                get: { mode },
                set: {
                    mode = $0
                    message = nil
                }
            )) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if mode == .signUp {
                AuthTextField(title: "Name", text: $name, contentType: .name)
            }

            AuthTextField(title: "Email", text: $email, keyboardType: .emailAddress, contentType: .emailAddress)
            AuthSecureField(title: "Password", text: $password)

            if let message {
                Text(message)
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseError)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: mode == .login ? "arrow.right.circle.fill" : "person.badge.plus.fill")
                    }
                    Text(mode == .login ? "Log In" : "Create Account")
                    Spacer()
                }
                .riseMainButton()
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.72 : 1)
        }
        .padding(22)
        .background(Color.riseSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.riseBorder, lineWidth: 1)
        )
    }

    private func submit() async {
        message = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            message = "Please enter your email and password."
            return
        }

        if mode == .signUp, trimmedName.isEmpty {
            message = "Please enter your name."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            switch mode {
            case .login:
                let token = try await api.login(email: trimmedEmail, password: password)
                authService.signIn(token: token)
            case .signUp:
                let result = try await api.signUp(name: trimmedName, email: trimmedEmail, password: password)
                switch result {
                case .signedIn(let token):
                    authService.signIn(token: token)
                case .verificationRequired(let text):
                    mode = .login
                    message = text
                    password = ""
                }
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func signInWithGoogle() {
        guard var components = URLComponents(url: LocalConfig.apiBaseURL, resolvingAgainstBaseURL: false) else {
            message = "Invalid authentication URL."
            return
        }
        components.path = "/auth/login/google"

        guard let authURL = components.url else {
            message = "Could not create Google authentication URL."
            return
        }

        isSubmitting = true
        message = nil

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: LocalConfig.oauthCallbackScheme) { callbackURL, error in
            Task { @MainActor in
                isSubmitting = false

                if let error {
                    if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        message = "Google authentication failed: \(error.localizedDescription)"
                    }
                    return
                }

                guard let callbackURL,
                      let token = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true)?
                        .queryItems?
                        .first(where: { $0.name == "token" })?
                        .value
                else {
                    message = "Could not complete Google sign in."
                    return
                }

                authService.signIn(token: token)
            }
        }

        session.presentationContextProvider = webAuthProvider
        webAuthSession = session
        if !session.start() {
            isSubmitting = false
            message = "Could not start Google authentication."
        }
    }

    private func signInWithApple() {
        isSubmitting = true
        message = nil

        appleAuthHandler = AppleAuthHandler(api: api) { result in
            isSubmitting = false
            switch result {
            case .success(let token):
                authService.signIn(token: token)
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        appleAuthHandler?.start()
    }
}

private struct SocialAuthButton: View {
    enum Style {
        case dark
        case light
    }

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: icon == "g.circle.fill" ? 22 : 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }
            .foregroundStyle(style == .dark ? Color.white : Color.riseText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .padding(.horizontal, 16)
            .background(style == .dark ? Color.riseBlack : Color.riseCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style == .dark ? Color.clear : Color.riseLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType?

    var body: some View {
        TextField(title, text: $text)
            .textInputAutocapitalization(.never)
            .keyboardType(keyboardType)
            .textContentType(contentType)
            .autocorrectionDisabled()
            .authFieldStyle()
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .textContentType(.password)
            .authFieldStyle()
    }
}

private extension View {
    func authFieldStyle() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.riseText)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.riseSoftFill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.riseLine, lineWidth: 1)
            )
    }
}
