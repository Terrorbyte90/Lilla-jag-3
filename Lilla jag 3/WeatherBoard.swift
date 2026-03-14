//
//  WeatherBoard.swift
//  DinApp
//
//  Skapad av Ted på 2025-07-26.
//  OBS! API‑nyckeln är hårdkodad tillfälligt – lagra den säkert i produktion.
//

import SwiftUI
import Charts
import Combine

// MARK: - OpenAI‑inställningar (från Config)
private enum WeatherAIConfig {
    static var apiKey: String { Config.openAIAPIKey }
    static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    static let model = "gpt-4o-mini"
}

// MARK: - Datamodeller
struct WeatherResponse: Decodable {
    let location: String
    let timestampUTC: String
    let sources: [String]
    let summary12h: String
    let current: Current
    let sunrise: String
    let sunset: String
    let rainRisk: Risk
    let thunderRisk: Risk
    let forecast: Forecast
    
    struct Current: Decodable {
        let temperatureC: Double
        let condition: String
        let humidity: Int
        let windKph: Double
    }
    struct Risk: Decodable {
        let within1h: Int
        let within3h: Int
        let within5h: Int
        let within8h: Int
        let minutesUntilNext: Int
    }
    struct Forecast: Decodable {
        let hourly: [Hourly]
        let daily: [Daily]
        
        struct Hourly: Decodable, Identifiable {
            let id = UUID()
            let datetimeLocalISO: String
            let temperatureC: Double
            let condition: String
            let rainProb: Int
            let thunderProb: Int?
        }
        struct Daily: Decodable, Identifiable {
            let id = UUID()
            let dateISO: String
            let minC: Double
            let maxC: Double
            let condition: String
            let rainProb: Int
            let thunderProb: Int
        }
    }
}

// MARK: - OpenAI‑klient
final class OpenAIWeatherClient {
    
    static let shared = OpenAIWeatherClient()
    private init() {}
    
    func fetchWeather(for location: String) async throws -> WeatherResponse {
        let systemPrompt =
        """
        Du är en hypernoggrann vädertjänst. Använd minst fem välrenommerade webbplatser \
        (t.ex. SMHI, YR, DMI, MeteoBlue, ECMWF) för att fastställa aktuellt väder och prognos. \
        Sammanställ all data till ett ENDA JSON‑objekt med följande struktur (exakt samma nycklar): \
        {
          "location": "...",
          "timestampUTC": "...",
          "sources": ["...", "...", "...", "...", "..."],
          "summary12h": "...",
          "current": {
            "temperatureC": 0,
            "condition": "...",
            "humidity": 0,
            "windKph": 0
          },
          "sunrise": "...",
          "sunset": "...",
          "rainRisk": { "within1h": 0, "within3h": 0, "within5h": 0, "within8h": 0, "minutesUntilNext": 0 },
          "thunderRisk": { "within1h": 0, "within3h": 0, "within5h": 0, "within8h": 0, "minutesUntilNext": 0 },
          "forecast": {
            "hourly": [
              { "datetimeLocalISO": "...", "temperatureC": 0, "condition": "...", "rainProb": 0, "thunderProb": 0 },
              ...
            ],
            "daily": [
              { "dateISO": "...", "minC": 0, "maxC": 0, "condition": "...", "rainProb": 0, "thunderProb": 0 },
              ...
            ]
          }
        }
        Returnera ENBART JSON utan kommentarer eller text runt omkring.
        Dagens datum är \(Date().formatted(date: .numeric, time: .omitted)) – använd det för att säkerställa att alla tidpunkter är aktuella.
        """
        
        let userPrompt = """
        Ange väderstatistik och prognoser för orten "\(location)" på svenska.
        Aktuellt datum: \(Date().formatted(date: .numeric, time: .omitted)).
        """
        
        let body: [String: Any] = [
            "model": WeatherAIConfig.model,
            "response_format": ["type": "json_object"],
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ]
        ]
        
        var request = URLRequest(url: WeatherAIConfig.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(WeatherAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let jsonString = decoded.choices.first?.message.content.data(using: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WeatherResponse.self, from: jsonString)
    }
}

// MARK: - ViewModel
@MainActor
final class WeatherBoardViewModel: ObservableObject {
    @Published var location = "Stockholm"
    @Published var updateInterval: Double = 30
    @Published var weather: WeatherResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var timer: AnyCancellable?
    
    func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }
    
    func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            weather = try await OpenAIWeatherClient.shared.fetchWeather(for: location)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - WeatherBoard
struct WeatherBoard: View {
    @StateObject private var vm = WeatherBoardViewModel()
    @FocusState private var searchFocused: Bool
    
    var body: some View {
        ZStack {
            // Dynamisk bakgrund
            LinearGradient(
                colors: gradientColors(),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Innehållet ligger kvar även under laddning
            VStack(spacing: 16) {
                header
                if let weather = vm.weather {
                    content(for: weather)
                } else if let error = vm.errorMessage {
                    Text("Fel: \(error)")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Spacer()
                    Text("Ingen data ännu.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding()
        }
        .onAppear {
            Task { await vm.refresh() }
            vm.startTimer()
        }
        .onDisappear { vm.stopTimer() }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Sök ort (svenska)", text: $vm.location, onCommit: {
                    Task { await vm.refresh() }
                })
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .submitLabel(.search)
                
                Button {
                    Task { await vm.refresh() }
                    searchFocused = false
                } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title2)
                }
                if vm.isLoading {
                    ProgressView()
                        .padding(.leading, 4)
                }
            }
            
            HStack {
                Text("Uppdateringsintervall: \(Int(vm.updateInterval)) s")
                Slider(value: $vm.updateInterval, in: 15...120, step: 15) {
                    Text("Intervall")
                } minimumValueLabel: {
                    Text("15")
                } maximumValueLabel: {
                    Text("120")
                }
                .onChange(of: vm.updateInterval) { vm.startTimer() }
            }
            .font(.caption)
            .opacity(0.8)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Innehåll
    @ViewBuilder
    private func content(for weather: WeatherResponse) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                currentWeatherCard(for: weather)
                summaryCard(for: weather)
                eventsCard(for: weather)
                riskCard(title: "Risk för regn", risk: weather.rainRisk)
                riskCard(title: "Risk för åska", risk: weather.thunderRisk)
                sunriseSunsetCard(weather: weather)
                forecastSelector(weather: weather)
                sourcesCard(sources: weather.sources)
            }
            .padding(.bottom, 32)
        }
    }
    private func summaryCard(for weather: WeatherResponse) -> some View {
        Text(weather.summary12h)
            .font(.body)
            .multilineTextAlignment(.leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Kortkomponenter
    private func currentWeatherCard(for weather: WeatherResponse) -> some View {
        VStack(spacing: 12) {
            Text(weather.location)
                .font(.largeTitle.bold())
            Text(weather.current.condition)
                .font(.title2)
            Text("\(Int(weather.current.temperatureC))°C")
                .font(.system(size: 64, weight: .thin))
            HStack(spacing: 20) {
                Label("\(weather.current.humidity)%", systemImage: "humidity.fill")
                Label(String(format: "%.0f km/h", weather.current.windKph), systemImage: "wind")
            }
            .font(.headline)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private func riskCard(title: String, risk: WeatherResponse.Risk) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            riskRow(label: "Inom 1 timme", value: risk.within1h)
            riskRow(label: "Inom 3 timmar", value: risk.within3h)
            riskRow(label: "Inom 5 timmar", value: risk.within5h)
            riskRow(label: "Inom 8 timmar", value: risk.within8h)
            Text("Nästa händelse om \(risk.minutesUntilNext) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private func riskRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)%")
        }
        .font(.subheadline)
    }

    // MARK: - Kommande händelser
    private struct WeatherEvent: Identifiable {
        let id = UUID()
        let time: Date
        let condition: String
    }

    private func transitionEvents(hourly: [WeatherResponse.Forecast.Hourly]) -> [WeatherEvent] {
        guard let first = hourly.first else { return [] }
        let iso = ISO8601DateFormatter()
        var previous = first.condition
        var events: [WeatherEvent] = []
        for hour in hourly.dropFirst() {
            guard let date = iso.date(from: hour.datetimeLocalISO) else { continue }
            if hour.condition != previous {
                events.append(WeatherEvent(time: date, condition: hour.condition))
                previous = hour.condition
            }
        }
        return events
    }

    private func eventsCard(for weather: WeatherResponse) -> some View {
        let events = transitionEvents(hourly: weather.forecast.hourly)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Kommande väderhändelser")
                .font(.headline)
            ForEach(events.prefix(5)) { ev in
                HStack {
                    Text(ev.time.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Image(systemName: symbol(for: ev.condition))
                    Text(ev.condition)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private func sunriseSunsetCard(weather: WeatherResponse) -> some View {
        HStack(spacing: 32) {
            VStack {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 28))
                Text(timeOnly(from: weather.sunrise))
            }
            Spacer()
            VStack {
                Image(systemName: "sunset.fill")
                    .font(.system(size: 28))
                Text(timeOnly(from: weather.sunset))
            }
        }
        .font(.title3)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Prognos
    @State private var forecastMode: ForecastMode = .day
    
    private enum ForecastMode: String, CaseIterable {
        case hour = "Timme"
        case day = "Dag"
        case week = "Vecka"
    }
    
    private func forecastSelector(weather: WeatherResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Prognos", selection: $forecastMode) {
                ForEach(ForecastMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            switch forecastMode {
            case .hour:
                VStack {
                    hourlyChart(hourly: weather.forecast.hourly)
                    hourlyList(hourly: Array(weather.forecast.hourly.prefix(24)))
                }
            case .day:
                dailyList(daily: Array(weather.forecast.daily.prefix(7)))
            case .week:
                dailyList(daily: weather.forecast.daily)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private func hourlyChart(hourly: [WeatherResponse.Forecast.Hourly]) -> some View {
        let iso = ISO8601DateFormatter()
        return Chart(hourly.prefix(24)) { hour in
            if let date = iso.date(from: hour.datetimeLocalISO) {
                LineMark(
                    x: .value("Tid", date),
                    y: .value("Temp", hour.temperatureC)
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
            }
        }
        .frame(height: 160)
    }
    
    private func dailySummary(daily: [WeatherResponse.Forecast.Daily]) -> some View {
        VStack {
            ForEach(daily) { day in
                HStack {
                    Text(formattedDate(day.dateISO))
                    Spacer()
                    Text("\(Int(day.minC))–\(Int(day.maxC))°C")
                    Image(systemName: symbol(for: day.condition))
                    Text("\(day.rainProb)%")
                        .foregroundStyle(.blue)
                    Text("\(day.thunderProb)%")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func hourlyList(hourly: [WeatherResponse.Forecast.Hourly]) -> some View {
        VStack(spacing: 2) {
            ForEach(hourly) { hour in
                HStack {
                    Text(timeOnly(from: hour.datetimeLocalISO))
                        .frame(width: 45, alignment: .leading)
                    Image(systemName: symbol(for: hour.condition))
                        .frame(width: 24)
                    Text("\(Int(hour.temperatureC))°C")
                        .frame(width: 45, alignment: .trailing)
                    Spacer(minLength: 8)
                    Text("\(hour.rainProb)%")
                        .frame(width: 32, alignment: .trailing)
                        .foregroundStyle(.blue)
                    if let thunder = hour.thunderProb {
                        Text("\(thunder)%")
                            .frame(width: 32, alignment: .trailing)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.footnote.monospacedDigit())
            }
        }
    }

    private func dailyList(daily: [WeatherResponse.Forecast.Daily]) -> some View {
        VStack(spacing: 4) {
            ForEach(daily) { day in
                HStack {
                    Text(weekdayOnly(from: day.dateISO))
                        .frame(width: 70, alignment: .leading)
                    Image(systemName: symbol(for: day.condition))
                        .frame(width: 24)
                    Text("\(Int(day.minC))–\(Int(day.maxC))°C")
                        .frame(width: 70, alignment: .trailing)
                    Spacer(minLength: 8)
                    Text("\(day.rainProb)%")
                        .frame(width: 32, alignment: .trailing)
                        .foregroundStyle(.blue)
                    Text("\(day.thunderProb)%")
                        .frame(width: 32, alignment: .trailing)
                        .foregroundStyle(.orange)
                }
                .font(.footnote.monospacedDigit())
            }
        }
    }
    
    private func formattedDate(_ isoString: String) -> String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func timeOnly(from isoString: String) -> String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func weekdayOnly(from isoString: String) -> String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }
    
    // MARK: - Källor
    private func sourcesCard(sources: [String]) -> some View {
        VStack(spacing: 8) {
            Text("För att ge den mest träffsäkra prognosen hämtas data från följande källor:")
                .multilineTextAlignment(.center)
                .font(.footnote)
            HStack {
                ForEach(sources, id: \.self) { src in
                    Label(src, systemImage: "link")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .font(.caption2)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Hjälpfunktioner
    private func gradientColors() -> [Color] {
        guard let condition = vm.weather?.current.condition.lowercased() else {
            return [Color.blue.opacity(0.6), Color.indigo]
        }
        if condition.contains("moln") {
            return [Color.gray.opacity(0.5), Color.blue.opacity(0.3)]
        }
        if condition.contains("regn") {
            return [Color.blue.opacity(0.7), Color.gray]
        }
        if condition.contains("snö") {
            return [Color.cyan.opacity(0.8), Color.white]
        }
        return [Color.orange, Color.pink]
    }
    
    private func symbol(for condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("sol") { return "sun.max.fill" }
        if lower.contains("moln") { return "cloud.fill" }
        if lower.contains("regn") { return "cloud.rain.fill" }
        if lower.contains("snö") { return "snow" }
        if lower.contains("åska") { return "cloud.bolt.rain.fill" }
        return "questionmark"
    }
}

// MARK: - Preview
struct WeatherBoard_Previews: PreviewProvider {
    static var previews: some View {
        WeatherBoard()
            .previewDevice("iPhone 15 Pro")
    }
}
