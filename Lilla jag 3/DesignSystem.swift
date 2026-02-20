import SwiftUI

struct DesignSystem {
    // MARK: - Colors
    enum Colors {
        static let background = Color(hex: 0x0F1123)
        static let backgroundSecondary = Color(hex: 0x171C38)
        static let accent = Color.blue
        static let accentSecondary = Color.purple
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let glassStroke = Color.white.opacity(0.15)
        static let glassFill = Color.white.opacity(0.05)
        
        static var brandGradient: LinearGradient {
            LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        
        static var backgroundGradient: LinearGradient {
            LinearGradient(colors: [background, backgroundSecondary], startPoint: .top, endPoint: .bottom)
        }
    }
    
    // MARK: - Typography
    enum Typography {
        static let titleLarge = Font.system(size: 34, weight: .black, design: .rounded)
        static let titleMain = Font.system(size: 28, weight: .bold, design: .rounded)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let caption = Font.caption.weight(.medium)
    }
    
    // MARK: - Corner Radii
    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 28
    }
}

// MARK: - View Modifiers
struct GlassModifier: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.glassFill)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DesignSystem.Colors.glassStroke, lineWidth: 1)
            )
    }
}

extension View {
    func ljGlassCard(radius: CGFloat = DesignSystem.Radius.medium) -> some View {
        modifier(GlassModifier(radius: radius))
    }
}

// MARK: - Global UI Components
struct LJTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.titleMain)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }
}

struct LJCard<Content: View>: View {
    let content: Content
    let radius: CGFloat
    
    init(radius: CGFloat = DesignSystem.Radius.medium, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .ljGlassCard(radius: radius)
    }
}
