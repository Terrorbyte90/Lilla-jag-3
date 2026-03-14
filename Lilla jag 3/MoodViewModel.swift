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

        // Lokal AI via LillaJagAIService – noll molnberoende
        let entrySummary = buildEntrySummary()
        weeklyReportText = await LillaJagAIService.shared.weeklyReport(summary: entrySummary)
    }

    private func buildEntrySummary() -> String {
        let last7 = store.last7()
        guard !last7.isEmpty else { return "Inga loggade dagar den senaste veckan." }

        let avgMood   = last7.map(\.moodQuality).average(default: 0)
        let avgSleep  = last7.map(\.sleepQuality).average(default: 0)
        let avgEnergy = last7.map(\.energyLevel).average(default: 0)
        let avgAnx    = last7.map(\.anxietyLevel).average(default: 0)

        return """
        Veckodata (\(last7.count) dagar):
        Mående: \(Int(avgMood * 100))%
        Sömn: \(Int(avgSleep * 100))%
        Energi: \(Int(avgEnergy * 100))%
        Ångest: \(Int(avgAnx * 100))%
        """
    }
}
