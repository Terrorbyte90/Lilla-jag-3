import SwiftUI

struct DesignSystem {
    // MARK: - Colors (varma, lugnande toner – ej kliniskt kalla)
    enum Colors {
        // Bakgrunder – djup varm lila
        static let background          = Color(hex: 0x1A1025)
        static let backgroundSecondary = Color(hex: 0x221535)

        // Accenter
        static let accent          = Color(hex: 0xBB86FC)   // varm lavendel
        static let accentSecondary = Color(hex: 0xFF6B8A)   // varm ros
        static let accentGold      = Color(hex: 0xFFD166)   // guld

        // Text
        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary  = Color.white.opacity(0.45)

        // Glass
        static let glassStroke   = Color.white.opacity(0.12)
        static let glassFill     = Color.white.opacity(0.06)

        // Danger / Crisis
        static let danger = Color(hex: 0xFF5B5B)

        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: 0xBB86FC), Color(hex: 0xFF6B8A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }

        static var backgroundGradient: LinearGradient {
            LinearGradient(colors: [background, backgroundSecondary], startPoint: .top, endPoint: .bottom)
        }

        static var subtleGradient: LinearGradient {
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Typography
    enum Typography {
        static let titleLarge   = Font.system(.largeTitle, design: .rounded, weight: .black)
        static let titleMain    = Font.system(.title2, design: .rounded, weight: .bold)
        static let titleSection = Font.system(.title3, design: .rounded, weight: .bold)
        static let headline     = Font.headline.weight(.semibold)
        static let body         = Font.body
        static let bodyRounded  = Font.system(.body, design: .rounded)
        static let caption      = Font.caption.weight(.medium)
        static let captionSmall = Font.caption2.weight(.medium)
        // Hero display – används för siffror och hero-element
        static let heroNumber   = Font.system(.largeTitle, design: .rounded, weight: .black)
    }

    // MARK: - Corner Radii
    enum Radius {
        static let small: CGFloat      = 12
        static let medium: CGFloat     = 18
        static let large: CGFloat      = 24
        static let extraLarge: CGFloat = 28
    }

    // MARK: - Adaptive Spacing (strikt 8pt-grid)
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48

        static func horizontalPadding(for width: CGFloat) -> CGFloat {
            max(16, width * 0.055)
        }

        static func cardSpacing(for height: CGFloat) -> CGFloat {
            height > 800 ? 24 : 16
        }
    }

    // MARK: - Adaptive Sizes
    enum Size {
        static func heroHeight(for screenHeight: CGFloat) -> CGFloat {
            min(max(screenHeight * 0.28, 180), 280)
        }
        static let minTapTarget: CGFloat    = 44
        static let iconCircleSmall: CGFloat  = 36
        static let iconCircleMedium: CGFloat = 44
        static let iconCircleLarge: CGFloat  = 52
    }

    // MARK: - Animation – kalibrerade spring-värden
    enum Animation {
        // Standard interaktiv respons – likt UIKit spring
        static let smooth = SwiftUI.Animation.spring(response: 0.38, dampingFraction: 0.82)
        // Snabb, tight – för toggle/selection
        static let quick  = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.72)
        // Mjuk intro – för cards som flyger in
        static let intro  = SwiftUI.Animation.spring(response: 0.55, dampingFraction: 0.78)
        // Linjär fade
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.45)
        // Overlay/dismiss
        static let overlay = SwiftUI.Animation.easeOut(duration: 0.3)
    }
}

// MARK: - Reduce Motion helper

extension EnvironmentValues {
    // Kortnamn för bekväm åtkomst i views
    var reduceMotion: Bool { accessibilityReduceMotion }
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

// Premium glasskort med subtil inre ljusreflex längs toppen
struct PremiumGlassModifier: ViewModifier {
    var radius: CGFloat
    var accentColor: Color

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    DesignSystem.Colors.glassFill
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.45)
                    )
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                accentColor.opacity(0.12),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func ljGlassCard(radius: CGFloat = DesignSystem.Radius.medium) -> some View {
        modifier(GlassModifier(radius: radius))
    }

    func ljPremiumCard(radius: CGFloat = DesignSystem.Radius.medium, accent: Color = .white) -> some View {
        modifier(PremiumGlassModifier(radius: radius, accentColor: accent))
    }

    /// Subtle press effect for interactive cards
    func ljPressable() -> some View {
        self.buttonStyle(LJPressableButtonStyle())
    }

    /// Reduce-motion-aware animation helper
    func ljAnimate<V: Equatable>(
        _ animation: SwiftUI.Animation = DesignSystem.Animation.smooth,
        value: V
    ) -> some View {
        self.modifier(ReduceMotionAnimationModifier(animation: animation, value: value))
    }
}

private struct ReduceMotionAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: SwiftUI.Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .none : animation, value: value)
    }
}

/// A button style that provides a subtle scale + opacity press effect
struct LJPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Haptic helpers

enum LJHaptic {
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft()      { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()   { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
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

// MARK: - Premium Icon Circle

struct LJIconCircle: View {
    let icon: String
    let color: Color
    var size: CGFloat = DesignSystem.Size.iconCircleMedium
    var iconScale: CGFloat = 0.42

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.25), color.opacity(0.08)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
            Image(systemName: icon)
                .font(.system(size: size * iconScale, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Section Header – konsekvent i hela appen

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let trailing, let action = trailingAction {
                Button(action: action) {
                    Text(trailing)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.warmLavender.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 2)
    }
}

// MARK: - Particle System (Premium Canvas-baserade partiklar)

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var radius: CGFloat
    var opacity: Double
    var color: Color
    var lifetime: Double
}

@MainActor
final class ParticleEngine: ObservableObject {
    @Published var particles: [Particle] = []
    private var timer: Timer?

    func emit(count: Int, at point: CGPoint, color: Color = .white) {
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 1...4)
            particles.append(Particle(
                x: point.x,
                y: point.y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                radius: CGFloat.random(in: 2...6),
                opacity: 1.0,
                color: color,
                lifetime: Double.random(in: 0.8...1.5)
            ))
        }
        startAnimation()
    }

    func emitConfetti(count: Int, in size: CGSize) {
        for _ in 0..<count {
            let colors: [Color] = [.warmLavender, .warmGold, .warmRose, .warmSage, .warmCoral]
            particles.append(Particle(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                vx: CGFloat.random(in: -2...2),
                vy: CGFloat.random(in: 2...5),
                radius: CGFloat.random(in: 4...8),
                opacity: 1.0,
                color: colors.randomElement() ?? .white,
                lifetime: Double.random(in: 3...5)
            ))
        }
        startAnimation()
    }

    /// Emits fire/flame particles from a given point — used for streak celebration.
    func emitFire(count: Int, at point: CGPoint) {
        let fireColors: [Color] = [
            Color(hex: 0xFF6B35),
            Color(hex: 0xFFD166),
            Color(hex: 0xFF4444),
            Color(hex: 0xFFAA00)
        ]
        for _ in 0..<count {
            let angle = CGFloat.random(in: (-0.7 * .pi)...(-0.3 * .pi)) // upward bias
            let speed = CGFloat.random(in: 1.5...4.5)
            particles.append(Particle(
                x: point.x + CGFloat.random(in: -8...8),
                y: point.y,
                vx: cos(angle) * speed * 0.4,
                vy: sin(angle) * speed,
                radius: CGFloat.random(in: 2.5...6),
                opacity: 1.0,
                color: fireColors.randomElement() ?? .warmGold,
                lifetime: Double.random(in: 0.6...1.2)
            ))
        }
        startAnimation()
    }

    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func update() {
        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vy += 0.05 // gravity
            particles[i].lifetime -= 1/60
            particles[i].opacity = max(0, particles[i].lifetime)
        }
        particles.removeAll { $0.opacity <= 0 }
        if particles.isEmpty {
            timer?.invalidate()
        }
    }
}

struct ParticleCanvas: View {
    let engine: ParticleEngine
    var body: some View {
        Canvas { context, _ in
            for particle in engine.particles {
                let rect = CGRect(
                    x: particle.x - particle.radius,
                    y: particle.y - particle.radius,
                    width: particle.radius * 2,
                    height: particle.radius * 2
                )
                context.fill(
                    Circle().path(in: rect),
                    with: .color(particle.color.opacity(particle.opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @StateObject private var engine = ParticleEngine()
    @State private var showConfetti = false

    var body: some View {
        ParticleCanvas(engine: engine)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: showConfetti) { _, newValue in
                if newValue {
                    engine.emitConfetti(count: 60, in: UIScreen.main.bounds.size)
                }
            }
    }

    func trigger() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showConfetti = false
        }
    }
}

// MARK: - Premium Glow Effects

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat
    var intensity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(intensity * 0.5), radius: radius * 2, x: 0, y: 0)
    }
}

extension View {
    func glow(color: Color = .warmLavender, radius: CGFloat = 20, intensity: Double = 0.6) -> some View {
        modifier(GlowModifier(color: color, radius: radius, intensity: intensity))
    }
}

// MARK: - Shimmer Effect (premium loading)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -300

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.3),
                            .init(color: .white.opacity(0.1), location: 0.5),
                            .init(color: .clear, location: 0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                            phase = geo.size.width + 300
                        }
                    }
                }
                .mask(content)
            )
    }
}

extension View {
    func ljShimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Floating Bubble Particles (Ambient Background Animation)

struct FloatingBubble: View {
    let size: CGFloat
    let color: Color
    let startX: CGFloat
    let duration: Double

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0.3
    @State private var xOffset: CGFloat = 0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.4), color.opacity(0.1)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: size * 0.15)
            .offset(x: startX + xOffset, y: yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    yOffset = -60
                    xOffset = 20
                    opacity = 0.6
                }
            }
    }
}

struct FloatingBubblesBackground: View {
    let bubbleCount: Int = 8

    private let colors: [Color] = [
        .warmLavender.opacity(0.3),
        .warmRose.opacity(0.25),
        .warmGold.opacity(0.2),
        .warmSage.opacity(0.25)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<bubbleCount, id: \.self) { index in
                FloatingBubble(
                    size: CGFloat.random(in: 80...200),
                    color: colors[index % colors.count],
                    startX: CGFloat.random(in: -100...300),
                    duration: Double.random(in: 8...15)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Premium Card Modifier with Metallic Shine

struct PremiumMetallicCardModifier: ViewModifier {
    var accentColor: Color
    var radius: CGFloat
    @State private var shimmerPhase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass layer
                    DesignSystem.Colors.glassFill
                    // Inner light gradient
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.3, y: 0.5)
                    )
                    // Shimmer sweep
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, shimmerPhase - 0.3)),
                            .init(color: Color.white.opacity(0.12), location: shimmerPhase),
                            .init(color: .clear, location: min(1, shimmerPhase + 0.3))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                accentColor.opacity(0.15),
                                accentColor.opacity(0.08),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.5
                }
            }
    }
}

extension View {
    /// Premium metallic card with shimmer sweep effect
    func ljMetallicCard(radius: CGFloat = DesignSystem.Radius.medium, accent: Color = .warmLavender) -> some View {
        modifier(PremiumMetallicCardModifier(accentColor: accent, radius: radius))
    }
}

struct LJSkeletonRow: View {
    var width: CGFloat = .infinity
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
            .ljShimmer()
    }
}

// MARK: - Morphing Pulse Button

struct MorphingPulseButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPulsing = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            LJHaptic.medium()
            action()
        }) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                        value: isPulsing
                    )

                // Middle glow ring
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 52, height: 52)

                // Inner circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.4), color.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1.5)
                    )

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Heart Burst Animation (Like Button)

struct HeartBurstView: View {
    let trigger: Bool

    @State private var particles: [(offset: CGSize, opacity: Double, scale: Double)] = []

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                if particles.indices.contains(index) {
                    Circle()
                        .fill(Color.warmRose)
                        .frame(width: 6, height: 6)
                        .offset(
                            x: particles[index].offset.width,
                            y: particles[index].offset.height
                        )
                        .opacity(particles[index].opacity)
                        .scaleEffect(particles[index].scale)
                }
            }
        }
        .onChange(of: trigger) { _, newValue in
            if newValue {
                emitBurst()
            }
        }
    }

    private func emitBurst() {
        particles = (0..<8).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 25...45)
            return (
                offset: CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                ),
                opacity: 1.0,
                scale: Double.random(in: 0.5...1.2)
            )
        }

        // Animate out
        withAnimation(.easeOut(duration: 0.5)) {
            particles = particles.map { p in
                (
                    offset: CGSize(width: p.offset.width * 2, height: p.offset.height * 2),
                    opacity: 0.0,
                    scale: p.scale * 1.5
                )
            }
        }
    }
}

// MARK: - Typewriter Effect

struct TypewriterText: View {
    let text: String
    let speed: Double // seconds per character

    @State private var displayedText = ""
    @State private var currentIndex = 0

    var body: some View {
        Text(displayedText)
            .onAppear {
                startTyping()
            }
    }

    private func startTyping() {
        guard currentIndex < text.count else { return }

        let charIndex = text.index(text.startIndex, offsetBy: currentIndex)
        displayedText += String(text[charIndex])
        currentIndex += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            startTyping()
        }
    }
}

// MARK: - Premium Switch Toggle

struct PremiumToggle: View {
    @Binding var isOn: Bool
    var accentColor: Color = .warmLavender

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.quick) {
                isOn.toggle()
            }
            LJHaptic.light()
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? accentColor : Color.white.opacity(0.15))
                    .frame(width: 52, height: 32)

                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .offset(x: isOn ? 10 : -10)
                    .animation(DesignSystem.Animation.quick, value: isOn)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animated Gradient Border

struct AnimatedGradientBorder: View {
    @State private var animateGradient = false

    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: [
                        .warmLavender,
                        .warmRose,
                        .warmGold,
                        .warmSage,
                        .warmLavender
                    ],
                    center: .center,
                    startAngle: .degrees(animateGradient ? 0 : 360),
                    endAngle: .degrees(animateGradient ? 360 : 0)
                ),
                lineWidth: lineWidth
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    animateGradient = true
                }
            }
    }
}

// MARK: - Staggered Appear Animation Modifier

struct StaggeredAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(DesignSystem.Animation.intro.delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(delay: Double) -> some View {
        modifier(StaggeredAppearModifier(delay: delay))
    }
}

// MARK: - Premium Progress Ring

struct PremiumProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradientColors: [Color]

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

// MARK: - Streak Fire View (Premium animated fire particles for streak card)

struct StreakFireView: View {
    let isActive: Bool
    @StateObject private var engine = ParticleEngine()
    @State private var timer: Timer?

    var body: some View {
        ParticleCanvas(engine: engine)
            .allowsHitTesting(false)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startFireTimer()
                } else {
                    timer?.invalidate()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    private func startFireTimer() {
        // Emit fire particles periodically for the streak glow effect
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            Task { @MainActor in
                engine.emitFire(count: 3, at: CGPoint(x: 21, y: 21))
            }
        }
    }
}

// MARK: - Hero Gradient Mesh (Animated gradient mesh background)

struct HeroGradientMesh: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let angle = now.remainder(dividingBy: .pi * 2)

                // Three gradient blobs that slowly orbit
                let blob1 = CGPoint(
                    x: size.width * (0.5 + 0.25 * cos(angle)),
                    y: size.height * (0.5 + 0.2 * sin(angle * 0.7))
                )
                let blob2 = CGPoint(
                    x: size.width * (0.5 + 0.3 * cos(angle + .pi * 2 / 3)),
                    y: size.height * (0.5 + 0.25 * sin(angle * 0.5 + .pi / 3))
                )
                let blob3 = CGPoint(
                    x: size.width * (0.5 + 0.2 * cos(angle + .pi * 4 / 3)),
                    y: size.height * (0.5 + 0.3 * sin(angle * 0.8 + .pi * 2 / 3))
                )

                let colors: [Color] = [.warmLavender, .warmRose, .warmGold]
                let points: [CGPoint] = [blob1, blob2, blob3]

                for i in 0..<3 {
                    let rect = CGRect(
                        x: points[i].x - 80,
                        y: points[i].y - 80,
                        width: 160,
                        height: 160
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .radialGradient(
                            Gradient(colors: [colors[i].opacity(0.35), colors[i].opacity(0)]),
                            center: points[i],
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Monster Glow Pulse (Animated glow for monster section)

struct MonsterGlowPulse: View {
    let isActive: Bool
    @State private var glowOpacity: Double = 0.4

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.warmLavender.opacity(glowOpacity - Double(ring) * 0.1), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60 + CGFloat(ring * 20)
                        )
                    )
                    .scaleEffect(1 + glowOpacity * 0.15 * CGFloat(ring))
            }
        }
        .opacity(isActive ? 1 : 0.2)
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.7
            }
        }
    }
}

// MARK: - 3D Rotation Card Effect (Premium KPI card tilt)

struct Card3DRotationEffect: ViewModifier {
    @State private var rotation: CGFloat = 0
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .onAppear {
                guard isEnabled else { return }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    rotation = 5
                }
            }
    }
}

extension View {
    func card3DRotation(isEnabled: Bool) -> some View {
        modifier(Card3DRotationEffect(isEnabled: isEnabled))
    }
}
