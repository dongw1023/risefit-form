import SwiftUI

extension Color {
    static let riseMint = Color(red: 0.54, green: 0.97, blue: 0.73)
    static let riseBlack = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let riseSurface = Color.white.opacity(0.05)
    static let riseBorder = Color.white.opacity(0.08)
    static let riseError = Color(red: 1.0, green: 0.46, blue: 0.35)
    static let riseWarning = Color(red: 1.0, green: 0.78, blue: 0.38)
    
    static let riseBgGradient = [
        Color(red: 0.04, green: 0.05, blue: 0.06),
        Color(red: 0.07, green: 0.08, blue: 0.09),
        Color(red: 0.02, green: 0.02, blue: 0.03)
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
            .foregroundStyle(color == .riseMint ? Color.black : .white)
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
