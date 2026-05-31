import SwiftUI

@main
struct RiseFitFormApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        if let token = authService.authToken {
            MainTabView(authToken: token)
        } else {
            AuthView()
        }
    }
}
