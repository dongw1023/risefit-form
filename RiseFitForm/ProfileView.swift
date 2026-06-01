import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @ObservedObject var viewModel: FormAnalysisViewModel

    private let privacyURL = URL(string: "https://risefitai.com/privacy")!
    private let termsURL = URL(string: "https://risefitai.com/terms")!
    
    var body: some View {
        ZStack {
            RiseAppBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    accountSection
                    aboutSection
                    signOutButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 100)
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
