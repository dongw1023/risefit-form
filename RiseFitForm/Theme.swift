import SwiftUI

extension Color {
    static let riseMint = Color(red: 0.18, green: 0.73, blue: 0.43)
    static let riseBlack = Color(red: 0.08, green: 0.10, blue: 0.09)
    static let riseText = Color(red: 0.08, green: 0.10, blue: 0.09)
    static let riseSecondaryText = Color(red: 0.38, green: 0.43, blue: 0.40)
    static let riseMutedText = Color(red: 0.58, green: 0.62, blue: 0.59)
    static let riseCard = Color(red: 1.0, green: 1.0, blue: 0.98)
    static let riseSurface = Color.riseCard
    static let riseSoftFill = Color(red: 0.91, green: 0.95, blue: 0.91)
    static let riseLine = Color(red: 0.84, green: 0.88, blue: 0.84)
    static let riseBorder = Color.riseLine
    static let riseTabBar = Color(red: 0.97, green: 0.99, blue: 0.96)
    static let riseError = Color(red: 0.86, green: 0.22, blue: 0.16)
    static let riseWarning = Color(red: 0.80, green: 0.52, blue: 0.10)
    
    static let riseBgGradient = [
        Color(red: 0.98, green: 1.0, blue: 0.97),
        Color(red: 0.94, green: 0.98, blue: 0.94),
        Color(red: 0.90, green: 0.95, blue: 0.91)
    ]
}

struct RisePanelModifier: ViewModifier {
    var padding: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.riseSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.riseBorder, lineWidth: 1)
            )
    }
}

struct RiseMainButtonModifier: ViewModifier {
    var color: Color = .riseMint
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(color == .riseMint ? Color.white : Color.riseText)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

struct RiseAppBackground: View {
    var body: some View {
        LinearGradient(
            colors: Color.riseBgGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

extension View {
    func risePanel(padding: CGFloat = 20) -> some View {
        modifier(RisePanelModifier(padding: padding))
    }
    
    func riseMainButton(color: Color = .riseMint) -> some View {
        modifier(RiseMainButtonModifier(color: color))
    }
    
    func riseFont(_ style: RiseFontStyle) -> some View {
        switch style {
        case .header:
            return self.font(.system(size: 34, weight: .black))
        case .title:
            return self.font(.system(size: 24, weight: .black))
        case .subtitle:
            return self.font(.system(size: 20, weight: .bold))
        case .bodyBold:
            return self.font(.system(size: 16, weight: .bold))
        case .bodyMedium:
            return self.font(.system(size: 14, weight: .medium))
        case .caption:
            return self.font(.system(size: 12, weight: .bold))
        }
    }
}

enum RiseFontStyle {
    case header
    case title
    case subtitle
    case bodyBold
    case bodyMedium
    case caption
}
