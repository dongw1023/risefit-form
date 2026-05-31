import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1
    @StateObject private var viewModel: FormAnalysisViewModel
    
    init(authToken: String?) {
        _viewModel = StateObject(wrappedValue: FormAnalysisViewModel(authToken: authToken))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    DashboardView(viewModel: viewModel)
                case 1:
                    AnalysisView(viewModel: viewModel)
                case 2:
                    ProfileView(viewModel: viewModel)
                default:
                    AnalysisView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await viewModel.loadHistory() }
                group.addTask { await viewModel.loadUserProfile() }
            }
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabItem(icon: "chart.bar.fill", label: "Dashboard", isSelected: selectedTab == 0) {
                withAnimation(.spring()) { selectedTab = 0 }
            }
            
            TabItem(icon: "waveform.path.ecg", label: "Analysis", isSelected: selectedTab == 1) {
                withAnimation(.spring()) { selectedTab = 1 }
            }
            
            TabItem(icon: "person.fill", label: "Profile", isSelected: selectedTab == 2) {
                withAnimation(.spring()) { selectedTab = 2 }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color.riseBlack.opacity(0.8)
                .background(.ultraThinMaterial)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
}

private struct TabItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.riseMint : .white.opacity(0.4))
                    .frame(height: 26)
                
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.riseMint : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
