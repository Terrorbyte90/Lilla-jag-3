import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var affirmation: String = AffirmationManager.random()
    @Published var showChatty = false
    @Published var showNumbers = false
    @Published var showCrisisPlan = false
    @Published var showDonation = false
    @Published var showForum = false
    @Published var showPsykolog = false
    @Published var showUkraine = false
    @Published var showSocial = false
    
    private var cancellables = Set<AnyCancellable>()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    init() {
        timer
            .sink { [weak self] _ in
                self?.affirmation = AffirmationManager.random()
            }
            .store(in: &cancellables)
    }
}
