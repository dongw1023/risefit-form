import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @ObservedObject var viewModel: FormAnalysisViewModel
    
    var body: some View {
        ZStack {
            RiseAppBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    accountSection
                    preferencesSection
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
                .foregroundStyle(.white)
            Text("Manage your account and preferences")
                .riseFont(.bodyBold)
                .foregroundStyle(Color.riseMint.opacity(0.85))
        }
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .riseFont(.subtitle)
                .foregroundStyle(.white)
            
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
                        .foregroundStyle(.white)
                    Text(viewModel.userProfile?.email ?? "Connected via RiseFit API")
                        .riseFont(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .risePanel()
        }
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .riseFont(.subtitle)
                .foregroundStyle(.white)
            
            VStack(spacing: 0) {
                PreferenceRow(icon: "camera.viewfinder", title: "Auto-detect Exercises", value: "Enabled")
                Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                PreferenceRow(icon: "bolt.horizontal.fill", title: "Subscription Tier", value: viewModel.userProfile?.tier.capitalized ?? "Free")
                Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                PreferenceRow(icon: "bell.fill", title: "Notifications", value: "On")
            }
            .background(Color.riseSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.riseBorder, lineWidth: 1)
            )
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Information")
                .riseFont(.subtitle)
                .foregroundStyle(.white)
            
            VStack(spacing: 0) {
                PreferenceRow(icon: "info.circle.fill", title: "App Version", value: "1.2.0")
                Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                PreferenceRow(icon: "shield.fill", title: "Privacy Policy", value: "")
                Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                PreferenceRow(icon: "doc.text.fill", title: "Terms of Service", value: "")
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
            .riseMainButton(color: Color.white.opacity(0.06))
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
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            Text(value)
                .riseFont(.bodyMedium)
                .foregroundStyle(.white.opacity(0.4))
            
            if value.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}
