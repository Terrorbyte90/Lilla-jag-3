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

// MARK: - 3  Snygg navbar (förbättrad med haptics & animationer)
struct Navbar: View {
    @ObservedObject private var router = NavRouter.shared
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10
    @Namespace private var tabAnimation

    private let gradient = LinearGradient(
        colors: [Color(hex: 0xBB86FC), Color(hex: 0xFF6B8A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NavDestination.allCases) { dest in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        router.current = dest
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: dest.icon)
                            .font(.system(size: min(iconSize, 24), weight: .semibold))
                            .scaleEffect(router.current == dest ? 1.1 : 1.0)
                        Text(dest.title)
                            .font(.system(size: min(labelSize, 12), weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(router.current == dest ? Color.white
                                                            : Color.primary.opacity(0.5))
                    .background(
                        Group {
                            if router.current == dest {
                                gradient
                                    .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                                    .clipShape(RoundedRectangle(cornerRadius: 14,
                                                                 style: .continuous))
                                    .shadow(color: Color(hex: 0xBB86FC).opacity(0.3), radius: 8, y: 2)
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: router.current)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dest.title)
                .accessibilityAddTraits(router.current == dest ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .padding(.horizontal, 12)
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
                            .padding(.bottom, 8) // Extra luft från botten
                    }
                    .onAppear { router.current = dest }   // säkerställ rätt markering
            } else {
                Color.clear     // inget visas om inte aktiv
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
