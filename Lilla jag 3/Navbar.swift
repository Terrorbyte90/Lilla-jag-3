//
//  Navbar.swift
//  Lilla Jag
//
//  ➜  Så använder du den:
//
//  1.  Lägg den här filen i projektet.
//  2.  I varje huvudsida lägger du **en rad**:
//
//          .withNavbar(dest: .chat)   // välj .home/.diary/.diagnoses/.chat/.mood
//
//      Exempel:
//
//          struct AssistantView: View {
//              var body: some View {
//                  Color.yellow.opacity(0.2)
//                      .overlay(Text("Prata").font(.largeTitle))
//                      .withNavbar(dest: .chat)      // ← en rad räcker
//              }
//          }
//
//  3.  Ha en enda “RootContainer” som staplar alla fem sidor i en ZStack
//      – modifieraren gör att bara den aktiva visas, resten är tomma.
//      Se preview längst ned.
//
//  Resultat:  Varje sida kan leva helt fristående, men växlar snyggt via NavRouter.
//

import SwiftUI

// MARK: - 1  Destinations­enum
enum NavDestination: String, CaseIterable, Identifiable {
    case home, diary, diagnoses, chat, mood
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .home:       return "Hem"
        case .diary:      return "Dagbok"
        case .diagnoses:  return "Diagnoser"
        case .chat:       return "Prata"
        case .mood:       return "Humör"
        }
    }
    var icon: String {
        switch self {
        case .home:       return "house.fill"
        case .diary:      return "book.closed.fill"
        case .diagnoses:  return "cross.case.fill"
        case .chat:       return "bubble.left.and.bubble.right.fill"
        case .mood:       return "face.smiling.fill"
        }
    }
}

// MARK: - 2  Global router (delad instans)
final class NavRouter: ObservableObject {
    static let shared = NavRouter()
    @Published var current: NavDestination = .home
}

// MARK: - 3  Premium Navbar
struct Navbar: View {
    @ObservedObject private var router = NavRouter.shared
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10
    @Namespace private var tabAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gradient = LinearGradient(
        colors: [Color(hex: 0xBB86FC), Color(hex: 0xFF6B8A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NavDestination.allCases) { dest in
                let isActive = router.current == dest
                Button {
                    LJHaptic.selection()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72)) {
                        router.current = dest
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: dest.icon)
                            .font(.system(size: min(iconSize, 22), weight: isActive ? .semibold : .regular))
                            .scaleEffect(isActive ? 1.08 : 1.0)
                            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: isActive)
                        Text(dest.title)
                            .font(.system(size: min(labelSize, 10), weight: isActive ? .semibold : .regular, design: .rounded))
                            .opacity(isActive ? 1.0 : 0.65)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.5))
                    .background(
                        Group {
                            if isActive {
                                gradient
                                    .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: Color(hex: 0xBB86FC).opacity(0.4), radius: 10, y: 3)
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: router.current)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dest.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 14)
    }
}

// MARK: - 4  Modifierare som växlar vyer
private struct NavbarModifier: ViewModifier {
    let dest: NavDestination
    @ObservedObject private var router = NavRouter.shared

    func body(content: Content) -> some View {
        Group {
            if router.current == dest {
                content
                    .safeAreaInset(edge: .bottom) {
                        Navbar()
                            .padding(.bottom, 6)
                    }
                    .transition(.opacity)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - 5  Publik helper
extension View {
    /// Använd på din sida så här:
    /// `.withNavbar(dest: .chat)`
    func withNavbar(dest: NavDestination) -> some View {
        modifier(NavbarModifier(dest: dest))
    }
}


// MARK: - 7  Root‑container som staplar alla vyer
struct RootContainer: View {
    var body: some View {
        ZStack {
            Dashboard().withNavbar(dest: .home)
            DagbokDashboardView().withNavbar(dest: .diary)
            DiagnoserView().withNavbar(dest: .diagnoses)
            AssistantView().withNavbar(dest: .chat)
            Mood1View().withNavbar(dest: .mood)
        }
        .animation(.easeInOut(duration: 0.25), value: NavRouter.shared.current)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - 8  Preview
#Preview {
    RootContainer()
        .preferredColorScheme(.dark)
}
