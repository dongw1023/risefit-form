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
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(Color.riseTabBar)
        .overlay(
            Rectangle()
                .fill(Color.riseLine)
                .frame(height: 1),
            alignment: .top
        )
        .shadow(color: Color.riseText.opacity(0.10), radius: 14, x: 0, y: -6)
        .ignoresSafeArea(edges: .bottom)
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
                    .foregroundStyle(isSelected ? Color.riseMint : Color.riseMutedText)
                    .frame(height: 26)
                
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.riseMint : Color.riseMutedText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
