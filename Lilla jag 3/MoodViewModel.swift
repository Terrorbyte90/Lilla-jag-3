import SwiftUI
import Combine

@MainActor
final class MoodViewModel: ObservableObject {
    @Published var showLogger = false
    @Published var selectedMetric = Metric.mood
    @Published var calendarExpanded = true
    @Published var calendarMonth = Date()
    @Published var popupEntry: MoodEntry?
    @Published var weeklyReportText: String = ""
    @Published var generatingWeekly = false
    
    let store: MoodStore
    
    init(store: MoodStore? = nil) {
        self.store = store ?? MoodStore()
    }
    
    func generateWeeklyReport() async {
        generatingWeekly = true
        defer { generatingWeekly = false }
        let corrs = store.correlations()
        do {
            weeklyReportText = try await OpenAIService.weeklyReport(entries: store.last7(), correlations: corrs)
        } catch {
            weeklyReportText = "Kunde inte generera rapport."
        }
    }
}
