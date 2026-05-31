import SwiftUI

// Deprecated in favor of MainTabView
struct ContentView: View {
    let authToken: String?
    
    var body: some View {
        MainTabView(authToken: authToken)
    }
}
