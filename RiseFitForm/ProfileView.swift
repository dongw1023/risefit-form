import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @ObservedObject var viewModel: FormAnalysisViewModel
    @State private var activeAlert: ProfileAlert?
    @State private var isDeletingAccount = false

    private let privacyURL = URL(string: "https://risefitai.com/privacy")!
    private let termsURL = URL(string: "https://risefitai.com/terms")!
    private let authAPI = AuthAPI()
    
    var body: some View {
        ZStack {
            RiseAppBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    accountSection
                    aboutSection
                    signOutButton
                    deleteAccountSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 72)
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .deleteConfirmation:
                return Alert(
                    title: Text("Delete Account?"),
                    message: Text("This submits an account deletion request and immediately disables access to your account. Your data will be retained until the deletion process is completed."),
                    primaryButton: .destructive(Text("Delete Account")) {
                        Task { await deleteAccount() }
                    },
                    secondaryButton: .cancel()
                )
            case .deletionError(let message):
                return Alert(
                    title: Text("Couldn’t Delete Account"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Profile")
                .riseFont(.header)
                .foregroundStyle(Color.riseText)
            Text("Manage your account and preferences")
                .riseFont(.bodyBold)
                .foregroundStyle(Color.riseMint.opacity(0.85))
        }
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)
            
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.riseMint.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    if let pictureURL = viewModel.userProfile?.picture, let url = URL(string: pictureURL) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView().tint(Color.riseMint)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.riseMint)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.userProfile?.name ?? "RiseFit Athlete")
                        .riseFont(.bodyBold)
                        .foregroundStyle(Color.riseText)
                    Text(viewModel.userProfile?.email ?? "Connected via RiseFit API")
                        .riseFont(.caption)
                        .foregroundStyle(Color.riseText.opacity(0.5))
                }
                
                Spacer()
            }
            .risePanel()
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Information")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)
            
            VStack(spacing: 0) {
                Link(destination: privacyURL) {
                    PreferenceRow(icon: "shield.fill", title: "Privacy Policy", value: "")
                }
                .buttonStyle(.plain)

                Divider().background(Color.riseText.opacity(0.05)).padding(.horizontal, 16)

                Link(destination: termsURL) {
                    PreferenceRow(icon: "doc.text.fill", title: "Terms of Service", value: "")
                }
                .buttonStyle(.plain)
            }
            .background(Color.riseSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.riseBorder, lineWidth: 1)
            )
        }
    }
    
    private var signOutButton: some View {
        Button {
            authService.signOut()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
                Spacer()
            }
            .riseMainButton(color: Color.riseText.opacity(0.06))
            .foregroundStyle(Color.riseError)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.riseError.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
    }

    private var deleteAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)

            Button {
                activeAlert = .deleteConfirmation
            } label: {
                HStack(spacing: 12) {
                    if isDeletingAccount {
                        ProgressView()
                            .tint(Color.riseError)
                    } else {
                        Image(systemName: "trash.fill")
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isDeletingAccount ? "Deleting Account…" : "Delete Account")
                            .riseFont(.bodyBold)
                        Text("Request account and data deletion")
                            .riseFont(.caption)
                            .foregroundStyle(Color.riseText.opacity(0.5))
                    }

                    Spacer()
                }
                .foregroundStyle(Color.riseError)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.riseSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.riseError.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)
        }
    }

    private func deleteAccount() async {
        guard let token = authService.authToken else {
            activeAlert = .deletionError("Your session has expired. Please sign in again.")
            return
        }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await authAPI.deleteAccount(token: token)
            authService.signOut()
        } catch {
            activeAlert = .deletionError(error.localizedDescription)
        }
    }
}

private enum ProfileAlert: Identifiable {
    case deleteConfirmation
    case deletionError(String)

    var id: String {
        switch self {
        case .deleteConfirmation:
            return "delete-confirmation"
        case .deletionError:
            return "deletion-error"
        }
    }
}

private struct PreferenceRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.riseMint)
                .frame(width: 32, height: 32)
                .background(Color.riseMint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(title)
                .riseFont(.bodyBold)
                .foregroundStyle(Color.riseText.opacity(0.9))
            
            Spacer()
            
            Text(value)
                .riseFont(.bodyMedium)
                .foregroundStyle(Color.riseText.opacity(0.4))
            
            if value.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.riseText.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}
