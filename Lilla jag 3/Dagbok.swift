// Dagbok.swift
// Lilla Jag – KBT-dagbok med ABC-modell

import SwiftUI

// MARK: - Data Model

struct DagbokEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date = .now
    var title: String = ""
    // ABC-modellen
    var activatingEvent: String = ""   // A – Händelse
    var belief: String = ""             // B – Automatisk tanke/tro
    var consequence: String = ""        // C – Känsla/beteende
    var alternativeThought: String = "" // Omstrukturerad tanke
    var emotion: String = "Ångest"
    var emotionIntensityBefore: Double = 0.7
    var emotionIntensityAfter: Double = 0.5
    var tags: [String] = []
    var aiInsight: String = ""
}

// MARK: - Store

@MainActor
final class DagbokStore: ObservableObject {
    static let shared = DagbokStore()

    @Published private(set) var entries: [DagbokEntry] = []
    private let url: URL

    init() {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = doc.appendingPathComponent("dagbok_entries.json")
        load()
        if entries.isEmpty { loadMockData() }
    }

    func add(_ entry: DagbokEntry) {
        var e = entry
        e.date = .now
        entries.insert(e, at: 0)
        save()
    }

    func update(_ entry: DagbokEntry) {
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i] = entry
            save()
        }
    }

    func delete(_ entry: DagbokEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? enc.encode(entries).write(to: url)
    }

    private func load() {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        guard let d = try? Data(contentsOf: url),
              let e = try? dec.decode([DagbokEntry].self, from: d) else { return }
        entries = e
    }

    private func loadMockData() {
        entries = [
            DagbokEntry(
                date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                title: "Svårt möte på jobbet",
                activatingEvent: "Min chef kritiserade min rapport framför hela teamet.",
                belief: "Jag är inkompetent och alla tänker illa om mig.",
                consequence: "Ångest och vilja att gömma mig.",
                alternativeThought: "Feedback är inte ett angrepp – alla kan förbättra sig.",
                emotion: "Skam",
                emotionIntensityBefore: 0.85,
                emotionIntensityAfter: 0.45,
                tags: ["Jobb", "Skam"],
                aiInsight: "Du visade mod att utmana den automatiska tanken 'inkompetent'."
            ),
            DagbokEntry(
                date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
                title: "Ensamhet på helgen",
                activatingEvent: "Vänner avbokade planer i sista minuten.",
                belief: "Ingen vill egentligen ha mig i sitt liv.",
                consequence: "Ledsamhet, isolering, ät för mycket.",
                alternativeThought: "Folk har sina egna liv – det handlar inte om mig.",
                emotion: "Nedstämdhet",
                emotionIntensityBefore: 0.75,
                emotionIntensityAfter: 0.5,
                tags: ["Relationer", "Ensamhet"],
                aiInsight: "Bra känt igen tankefällan 'personalisering'."
            )
        ]
    }
}

// MARK: - DagbokDashboardView

struct DagbokDashboardView: View {
    @ObservedObject private var store = DagbokStore.shared
    @State private var showNewEntry = false
    @State private var selectedEntry: DagbokEntry? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                WarmBackground()

                VStack(spacing: 0) {
                    dagbokHeader
                    Divider().opacity(0.15)

                    if store.entries.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(store.entries) { entry in
                                    EntryCard(entry: entry)
                                        .onTapGesture { selectedEntry = entry }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 110)
                        }
                    }
                }

                // FAB – ny anteckning
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showNewEntry = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(DesignSystem.Colors.brandGradient)
                                .clipShape(Circle())
                                .shadow(color: DesignSystem.Colors.accent.opacity(0.5), radius: 16, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.bottom, 96)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNewEntry) {
            ABCEntryView { entry in
                store.add(entry)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry, store: store)
        }
    }

    private var dagbokHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tankedagbok")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                Text("\(store.entries.count) anteckningar")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundStyle(Color.warmGold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            LJEmptyState(
                icon: "book.closed",
                title: "Din dagbok är tom",
                subtitle: "Tryck på + för att skapa din första KBT-anteckning med ABC-modellen.",
                actionLabel: "Ny anteckning",
                onAction: { showNewEntry = true }
            )
            Spacer()
        }
    }
}

// MARK: - Entry Card

struct EntryCard: View {
    let entry: DagbokEntry

    private var dateString: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.unitsStyle = .short
        return f.localizedString(for: entry.date, relativeTo: .now)
    }

    private var intensityChange: Double {
        entry.emotionIntensityBefore - entry.emotionIntensityAfter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title.isEmpty ? "Anteckning" : entry.title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                EmotionBadge(emotion: entry.emotion)
            }

            Text(entry.activatingEvent)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)

            // Intensitetsminskning
            if intensityChange > 0.05 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.warmSage)
                        .font(.caption)
                    Text(String(format: "Intensitet minskade %.0f%%", intensityChange * 100))
                        .font(.caption2)
                        .foregroundStyle(Color.warmSage)
                }
            }

            // Taggar
            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.1), in: Capsule())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.glassMedium,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .ljShadowSmall()
    }
}

struct EmotionBadge: View {
    let emotion: String

    private var color: Color {
        switch emotion {
        case "Ångest":     return .warmLavender
        case "Nedstämdhet": return Color(hex: 0x6B8DD6)
        case "Ilska":      return .warmCoral
        case "Skam":       return Color(hex: 0xFF8FAD)
        case "Ensamhet":   return Color(hex: 0x7EC8E3)
        default:           return .warmGold
        }
    }

    var body: some View {
        Text(emotion)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - ABC Entry View (ny anteckning)

struct ABCEntryView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (DagbokEntry) -> Void

    @State private var entry = DagbokEntry()
    @State private var step = 0
    @State private var isGeneratingInsight = false

    private let emotions = ["Ångest", "Nedstämdhet", "Ilska", "Skam", "Ensamhet", "Stress", "Oro", "Skuld"]
    private let tagOptions = ["Jobb", "Relationer", "Familj", "Hälsa", "Ekonomi", "Framtid", "Kropp", "Socialt"]

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                VStack(spacing: 0) {
                    // Progress
                    ProgressView(value: Double(step + 1), total: 6)
                        .tint(Color.warmGold)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Text("Steg \(step + 1) av 6")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 4)

                    ScrollView {
                        VStack(spacing: 24) {
                            stepContent
                        }
                        .padding(20)
                    }

                    // Navigation buttons
                    HStack(spacing: 12) {
                        if step > 0 {
                            Button("Tillbaka") { withAnimation { step -= 1 } }
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Button(step < 5 ? "Nästa" : "Spara") {
                            if step < 5 {
                                withAnimation { step += 1 }
                            } else {
                                saveEntry()
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.warmGold, in: RoundedRectangle(cornerRadius: 14))
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .background(.ultraThinMaterial)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            stepCard(icon: "doc.text", color: .warmGold, title: "Ge din anteckning en titel") {
                TextField("Ex: Svårt möte med chef", text: $entry.title)
                    .abcField()
            }

        case 1:
            stepCard(icon: "A.circle.fill", color: Color(hex: 0xFF8C69), title: "A – Utlösande händelse") {
                Text("Vad hände? Beskriv situationen så objektivt som möjligt.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                TextEditor(text: $entry.activatingEvent)
                    .frame(minHeight: 100)
                    .abcTextEditor()
                    .placeholder("Min chef sa att min rapport var dålig framför alla...", text: $entry.activatingEvent)
            }

        case 2:
            stepCard(icon: "B.circle.fill", color: Color.warmLavender, title: "B – Automatisk tanke/tro") {
                Text("Vad tänkte du direkt? Vilken tro triggades?")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                TextEditor(text: $entry.belief)
                    .frame(minHeight: 80)
                    .abcTextEditor()
                    .placeholder("Jag är värdelös och inkompetent...", text: $entry.belief)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Känsla")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(emotions, id: \.self) { e in
                            Button {
                                entry.emotion = e
                            } label: {
                                Text(e)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(entry.emotion == e ? .black : .white)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(entry.emotion == e ? Color.warmLavender : Color.white.opacity(0.1),
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Intensitet: \(Int(entry.emotionIntensityBefore * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Slider(value: $entry.emotionIntensityBefore, in: 0...1)
                        .tint(Color.warmLavender)
                }
            }

        case 3:
            stepCard(icon: "C.circle.fill", color: Color.warmRose, title: "C – Konsekvens") {
                Text("Vad hände sen? Hur reagerade du? Vad undvek du?")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                TextEditor(text: $entry.consequence)
                    .frame(minHeight: 80)
                    .abcTextEditor()
                    .placeholder("Jag gick hem och isolerade mig...", text: $entry.consequence)
            }

        case 4:
            stepCard(icon: "arrow.triangle.2.circlepath", color: Color.warmSage, title: "Omstrukturera tanken") {
                Text("Vad är ett mer nyanserat, balanserat sätt att se på situationen?")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text("Tips: Vad hade du sagt till en vän i samma situation?")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .italic()
                TextEditor(text: $entry.alternativeThought)
                    .frame(minHeight: 80)
                    .abcTextEditor()
                    .placeholder("Feedback är inte ett personangrepp. Jag kan lära mig...", text: $entry.alternativeThought)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hur stark är känslan nu? \(Int(entry.emotionIntensityAfter * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Slider(value: $entry.emotionIntensityAfter, in: 0...1)
                        .tint(Color.warmSage)
                }
            }

        case 5:
            stepCard(icon: "tag.fill", color: Color.warmGold, title: "Taggar") {
                Text("Välj kategorier för att hitta mönster.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(tagOptions, id: \.self) { tag in
                        Button {
                            if entry.tags.contains(tag) {
                                entry.tags.removeAll { $0 == tag }
                            } else {
                                entry.tags.append(tag)
                            }
                        } label: {
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(entry.tags.contains(tag) ? .black : .white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(entry.tags.contains(tag) ? Color.warmGold : Color.white.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        default:
            EmptyView()
        }
    }

    private func stepCard<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private func saveEntry() {
        let entryToSave = entry
        dismiss()
        // Generera AI-insikt asynkront
        Task {
            let fullText = "\(entryToSave.activatingEvent) \(entryToSave.belief) \(entryToSave.consequence)"
            let insight = await LillaJagAIService.shared.analyzeDiaryEntry(fullText)
            var updated = entryToSave
            updated.aiInsight = insight
            onSave(updated)
        }
    }
}

// MARK: - Entry Detail View

struct EntryDetailView: View {
    let entry: DagbokEntry
    let store: DagbokStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentEntry: DagbokEntry
    @State private var loadingInsight = false

    init(entry: DagbokEntry, store: DagbokStore) {
        self.entry = entry
        self.store = store
        self._currentEntry = State(initialValue: entry)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(currentEntry.title.isEmpty ? "Anteckning" : currentEntry.title)
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.white)

                        detailSection(letter: "A", color: Color(hex: 0xFF8C69), title: "Händelse", text: currentEntry.activatingEvent)
                        detailSection(letter: "B", color: Color.warmLavender, title: "Automatisk tanke", text: currentEntry.belief)
                        detailSection(letter: "C", color: Color.warmRose, title: "Konsekvens", text: currentEntry.consequence)
                        detailSection(letter: "→", color: Color.warmSage, title: "Omstrukturerad tanke", text: currentEntry.alternativeThought)

                        // Intensitetsjämförelse
                        HStack(spacing: 16) {
                            VStack {
                                Text("Före")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(Int(currentEntry.emotionIntensityBefore * 100))%")
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.warmRose)
                            }
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.white.opacity(0.4))
                            VStack {
                                Text("Efter")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(Int(currentEntry.emotionIntensityAfter * 100))%")
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.warmSage)
                            }
                            Spacer()
                            EmotionBadge(emotion: currentEntry.emotion)
                        }
                        .padding()
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

                        // AI-insikt
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundStyle(Color.warmLavender)
                                    Text("AI-insikt")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.warmLavender)
                                }
                                Spacer()
                                Button {
                                    refreshInsight()
                                } label: {
                                    if loadingInsight {
                                        ProgressView().tint(.white).scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(loadingInsight)
                            }
                            if currentEntry.aiInsight.isEmpty {
                                Text("Tryck på ↻ för att generera en KBT-insikt")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                            } else {
                                Text(currentEntry.aiInsight)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineSpacing(3)
                            }
                        }
                        .padding()
                        .background(Color.warmLavender.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.warmLavender.opacity(0.15), lineWidth: 1))
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        store.delete(entry)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
        }
    }

    private func refreshInsight() {
        loadingInsight = true
        Task {
            let fullText = "\(currentEntry.activatingEvent) \(currentEntry.belief) \(currentEntry.consequence)"
            let insight = await LillaJagAIService.shared.analyzeDiaryEntry(fullText)
            currentEntry.aiInsight = insight
            store.update(currentEntry)
            loadingInsight = false
        }
    }

    private func detailSection(letter: String, color: Color, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(letter)
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.15), in: Circle())
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(text.isEmpty ? "–" : text)
                .font(.body)
                .foregroundStyle(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - TextField helpers

extension View {
    func abcField() -> some View {
        self
            .padding(12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
    }

    func abcTextEditor() -> some View {
        self
            .padding(8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .scrollContentBackground(.hidden)
    }

    func placeholder(_ text: String, text binding: Binding<String>) -> some View {
        self.overlay(
            Group {
                if binding.wrappedValue.isEmpty {
                    Text(text)
                        .foregroundStyle(.white.opacity(0.25))
                        .font(.callout)
                        .allowsHitTesting(false)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        )
    }
}

// MARK: - Previews

#Preview("Dagbok") {
    DagbokDashboardView()
        .preferredColorScheme(.dark)
}

#Preview("Ny anteckning") {
    ABCEntryView { _ in }
}
