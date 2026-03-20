// LillaJagAI.swift
// Lilla Jag – Lokal AI-motor
//
// Arkitektur (tre lager):
//   1. QwenEngine       – Qwen 2.5 CoreML när modell finns i bundle
//   2. LillaJagMLEngine – Emotion/sentiment-analys (KB-BERT + CoreML classifiers)
//   3. KBTFallback      – Evidensbaserade KBT-svar (körs alltid offline)
//
// LillaJagAIService är det enda gränssnitt som alla vyer använder.

import Foundation
import SwiftUI

// MARK: - ChatMessage

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date
    var emotion: EmotionResult?

    init(role: Role, content: String, timestamp: Date = .now, emotion: EmotionResult? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.emotion = emotion
    }

    enum Role: String, Codable {
        case user, assistant, system
    }
}

// MARK: - LillaJagAIService (singleton)

@MainActor
final class LillaJagAIService: ObservableObject {
    static let shared = LillaJagAIService()

    @Published var isThinking = false
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var currentEmotion: EmotionResult?

    // Senaste analys av konversationens emotionella tillstånd
    @Published private(set) var sessionSentiment: Float = 0.0

    private let systemPrompt = """
    Du är "Lilla Jag" – en varm, empatisk och vetenskapligt förankrad KBT-coach.
    Du jobbar enligt Kognitiv Beteendeterapi (KBT), ACT och Sokratisk dialog.

    Dina kärnprinciper:
    • Alltid på svenska, varmt och icke-dömande
    • Ställ Sokratiska frågor – utmana försiktigt tankar, aldrig personen
    • Använd ABC-modellen (Händelse → Tanke → Känsla/Beteende)
    • Validera känslor INNAN du erbjuder nya perspektiv
    • Identifiera kognitiva distortioner varsamt
    • Föreslå konkreta, små beteendeexperiment
    • Om krisläge: hänvisa direkt till Självmordslinjen 90101
    • Svara med max 3-4 meningar, sedan en öppen fråga
    • Inga punktlistor i konversation – skriv naturligt, som en terapeut
    """

    // MARK: - Modell-status

    var modelName: String {
        "Lilla Jag KBT (lokal)"
    }

    // MARK: - Generera svar (huvud-API)

    func generateResponse(to userMessage: String) async -> String {
        isThinking = true
        defer { isThinking = false }

        // Återanvänd emotion från det senast tillagda user-meddelandet om det matchar,
        // annars analysera (undviker dubbel ML-inferens vid normal sendMessage-flöde).
        let emotion: EmotionResult
        if let last = messages.last(where: { $0.role == .user && $0.content == userMessage }),
           let cachedEmotion = last.emotion {
            emotion = cachedEmotion
        } else {
            emotion = await LillaJagMLEngine.shared.analyzeEmotion(userMessage)
        }

        let sentiment = await LillaJagMLEngine.shared.analyzeSentiment(userMessage)

        // Uppdatera aktuellt emotionellt tillstånd
        currentEmotion = emotion
        sessionSentiment = sessionSentiment * 0.7 + sentiment * 0.3 // exponentiellt glidande medelvärde

        // Försök med Qwen om modell finns.
        // Bygg historiken från alla meddelanden UTOM det sista (som redan är userMessage).
        let qwen = QwenEngine.shared
        let historyForQwen = messages.dropLast().suffix(7).map { msg in
            (role: msg.role == .user ? "user" : "assistant", content: msg.content)
        }

        let qwenResponse = await qwen.generate(
            systemPrompt: systemPrompt,
            conversationHistory: Array(historyForQwen),
            userMessage: userMessage,
            maxNewTokens: 250,
            temperature: 0.75
        )

        if !qwenResponse.isEmpty {
            return qwenResponse
        }

        // Fallback: KBT-motor + emotion-aware svar
        let thinkTime = Double.random(in: 0.6...1.4)
        try? await Task.sleep(nanoseconds: UInt64(thinkTime * 1_000_000_000))
        return KBTFallback.response(for: userMessage, history: messages, emotion: emotion)
    }

    // MARK: - Konversationshantering

    func addUserMessage(_ text: String) async {
        let emotion = await LillaJagMLEngine.shared.analyzeEmotion(text)
        messages.append(ChatMessage(role: .user, content: text, emotion: emotion))
    }

    func addAssistantMessage(_ text: String) {
        messages.append(ChatMessage(role: .assistant, content: text))
    }

    func newSession() {
        messages = []
        currentEmotion = nil
        sessionSentiment = 0
    }

    func welcomeMessage(name: String? = nil) -> String {
        let greeting = name.map { "Hej \($0)!" } ?? "Hej!"
        return "\(greeting) Jag är här för dig. Vad bär du på just nu?"
    }

    // MARK: - Analysera humörlogg

    func analyzeMoodEntry(_ entryDescription: String) async -> (summary: String, insights: [String], advice: [String]) {
        isThinking = true
        defer { isThinking = false }

        let emotion = await LillaJagMLEngine.shared.analyzeEmotion(entryDescription)
        let sentiment = await LillaJagMLEngine.shared.analyzeSentiment(entryDescription)

        try? await Task.sleep(nanoseconds: 400_000_000)
        return KBTFallback.moodInsights(for: entryDescription, emotion: emotion, sentiment: sentiment)
    }

    // MARK: - Veckorapport
    // Skickar vidare rå summary-sträng – om anroparen bygger den med nyckelformat
    // "mood:0.6,anxiety:0.4,sleep:0.7,outdoor:0.5,social:0.6,streak:4,logsCount:5"
    // genereras en fullt personaliserad rapport; annars generisk rapport.

    func weeklyReport(summary: String) async -> String {
        isThinking = true
        defer { isThinking = false }
        try? await Task.sleep(nanoseconds: 400_000_000)
        return KBTFallback.weeklyReport(summary: summary)
    }

    // MARK: - Krisplan-stöd

    func crisisGrounding() async -> String {
        isThinking = true
        defer { isThinking = false }
        try? await Task.sleep(nanoseconds: 300_000_000)
        return KBTFallback.groundingExercise()
    }

    func crisisCopingSuggestions(warningSigns: String) async -> [String] {
        isThinking = true
        defer { isThinking = false }

        let emotion = await LillaJagMLEngine.shared.analyzeEmotion(warningSigns)
        try? await Task.sleep(nanoseconds: 300_000_000)
        return KBTFallback.copingSuggestions(for: emotion)
    }

    // MARK: - Krisnummer-stöd

    func preCallGrounding() async -> String {
        isThinking = true
        defer { isThinking = false }
        try? await Task.sleep(nanoseconds: 300_000_000)
        return KBTFallback.preCallGrounding()
    }

    // MARK: - Socialt stöd

    func socialEncouragement() async -> String {
        isThinking = true
        defer { isThinking = false }

        let sentiment = sessionSentiment
        try? await Task.sleep(nanoseconds: 300_000_000)
        return KBTFallback.socialEncouragement(sentiment: sentiment)
    }

    // MARK: - Donationsmotivation

    func donationMotivation() async -> String {
        isThinking = true
        defer { isThinking = false }
        try? await Task.sleep(nanoseconds: 200_000_000)
        return KBTFallback.donationMotivation()
    }

    // MARK: - Monster AI-tips

    func monsterInsight(for log: DailyLog) async -> String {
        isThinking = true
        defer { isThinking = false }

        let description = log.prompt
        let emotion = await LillaJagMLEngine.shared.analyzeEmotion(description)
        let sentiment = await LillaJagMLEngine.shared.analyzeSentiment(description)
        try? await Task.sleep(nanoseconds: 300_000_000)
        return KBTFallback.monsterInsight(log: log, emotion: emotion, sentiment: sentiment)
    }

    // MARK: - Analysera dagboksinlägg (KBT-dagbok)

    func analyzeDiaryEntry(_ abcEntry: String) async -> String {
        isThinking = true
        defer { isThinking = false }

        let emotion = await LillaJagMLEngine.shared.analyzeEmotion(abcEntry)

        let qwen = QwenEngine.shared
        let qwenResponse = await qwen.generate(
            systemPrompt: "Du är en KBT-terapeut som analyserar ABC-modellen. Ge en kort, empatisk insikt på svenska (max 3 meningar) om vad du ser i detta dagboksinlägg och erbjud ett omstrukturerande perspektiv.",
            conversationHistory: [],
            userMessage: abcEntry,
            maxNewTokens: 150
        )

        if !qwenResponse.isEmpty { return qwenResponse }

        try? await Task.sleep(nanoseconds: 400_000_000)
        return KBTFallback.diaryInsight(emotion: emotion)
    }
}

// MARK: - KBT Fallback Motor

private enum KBTFallback {

    private enum Topic {
        case kris, ångest, nedstämdhet, sömnproblem, ensamhet,
             stress, ilska, skam, relationer, motivation, allmän
    }

    // MARK: - Tidskontext
    // Ger KBT-motorn medvetenhet om tid på dygnet och veckodag,
    // vilket möjliggör mer träffsäkra, kontextuella svar.

    private enum TimeOfDay {
        case earlyMorning  // 04–07
        case morning       // 07–12
        case afternoon     // 12–17
        case evening       // 17–21
        case night         // 21–04

        static var current: TimeOfDay {
            let h = Calendar.current.component(.hour, from: Date())
            switch h {
            case 4..<7:  return .earlyMorning
            case 7..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default:     return .night
            }
        }

        /// Kontextmedveten inledning för AI-svaret baserat på tid
        var contextualPrefix: String? {
            switch self {
            case .earlyMorning:
                return "Det är tidigt på morgonen – att tankarna snurrar i gryningen är vanligt, det kallas ibland 'gryningsdepression'."
            case .night:
                return "Sent på natten kan känslor och tankar bli mer intensiva – sömnbrist förstärker allt."
            default:
                return nil
            }
        }
    }

    /// Detekterar om konversationen visar tecken på progression (eskalering eller förbättring)
    private static func detectConversationTrend(history: [ChatMessage]) -> String? {
        guard history.count >= 4 else { return nil }
        // Titta på om de senaste användarmeddelandena innehåller mer positiva signaler
        let recentUserMessages = history.suffix(4).filter { $0.role == .user }.map { $0.content.lowercased() }
        let positiveSignals = ["bättre", "tack", "hjälper", "lättare", "förstår"]
        let hasProgress = recentUserMessages.contains { msg in
            positiveSignals.contains { msg.contains($0) }
        }
        return hasProgress ? "Jag märker att du verkar ha hittat lite mer klarhet i det vi pratat om." : nil
    }

    static func response(for input: String, history: [ChatMessage], emotion: EmotionResult) -> String {
        let lower = input.lowercased()

        // Krisläge – alltid prioritet
        if containsAny(lower, ["suicid", "ta livet", "dö", "döda mig",
                               "inte leva", "hopplöst", "orkar inte mer"]) {
            return "Det låter som du har det väldigt tungt just nu, och jag vill att du vet att du inte är ensam. Ring Självmordslinjen på 90101 – de finns dygnet runt och lyssnar utan att döma. Kan du ringa dem nu?"
        }

        let topic = detectTopic(lower, emotion: emotion)
        let isFollowUp = history.count > 2

        // Bygg svaret med eventuell tidskontext och konversationsprogressionsdetektion
        var response = topicResponse(topic, input: input, isFollowUp: isFollowUp, emotion: emotion)

        // Lägg till tidskontext om relevant (bara för natt/gryning och inte krisläge)
        if topic != .kris, let prefix = TimeOfDay.current.contextualPrefix {
            response = "\(prefix) \(response)"
        }

        // Bekräfta progression om den detekteras
        if isFollowUp, let trend = detectConversationTrend(history: history), !response.hasPrefix(trend) {
            // Lägg till progressionsigenkänning var 5:e meddelande för att undvika repetition
            if history.count % 5 == 0 {
                response = "\(trend) \(response)"
            }
        }

        return response
    }

    private static func detectTopic(_ input: String, emotion: EmotionResult) -> Topic {
        // Prioritera emotion-baserad detektion
        let dom = emotion.dominant.name
        if dom == "rädsla" || containsAny(input, ["panik", "ångest", "hjärtat", "andas", "rädd", "oro"]) { return .ångest }
        if dom == "sorg" || containsAny(input, ["ledsen", "trist", "depression", "tom", "meningslös", "gråter"]) { return .nedstämdhet }
        if dom == "ilska" || containsAny(input, ["arg", "ilsken", "explosiv", "frustrerad", "irriterad"]) { return .ilska }
        if containsAny(input, ["sover", "sömn", "trött", "vaknar", "natt"]) { return .sömnproblem }
        if containsAny(input, ["ensam", "ingen", "vänner", "isolerad", "saknar"]) { return .ensamhet }
        if containsAny(input, ["stress", "pressat", "hinner", "krav", "jobb", "skola"]) { return .stress }
        if containsAny(input, ["skam", "skämms", "dålig", "värdelös", "misslyckad"]) { return .skam }
        if containsAny(input, ["relation", "partner", "kärlek", "bråk", "separation"]) { return .relationer }
        if containsAny(input, ["motivat", "orkar", "energi", "gör ingenting", "fastnat"]) { return .motivation }
        if containsAny(input, ["kris", "akut", "hjälp", "klarar", "bryta"]) { return .kris }
        return .allmän
    }

    private static func topicResponse(_ topic: Topic, input: String, isFollowUp: Bool, emotion: EmotionResult) -> String {
        switch topic {
        case .ångest:
            let responses = [
                "Ångest kan kännas överväldigande, som om faran är verklig just nu. Det din hjärna gör är faktiskt ett försök att skydda dig. Vad tänker du att det värsta som kan hända är, i den här situationen?",
                "Jag hör att du känner dig rädd. Låt oss stanna upp ett ögonblick – nämn fem saker du kan se runt dig just nu. Det hjälper nervsystemet att landa i nuet.",
                "Ångest föder ofta tanken att vi måste undvika det som skrämmer oss. Men vad tror du skulle hända om du stannade kvar i känslan i 30 sekunder, istället för att fly?"
            ]
            return responses.randomElement()!

        case .nedstämdhet:
            let responses = [
                "Att känna tomhet och ledsamhet är genuint svårt, och du förtjänar att få det validerat. Depression ljuger ofta – den säger att ingenting hjälper. Vad är en liten, liten sak du gjort idag som du kan ge dig credit för?",
                "Jag hör dig, och jag vill att du vet att det är modigt att berätta. Nedstämdhet krymper ofta vår syn på framtiden. Kan du komma ihåg ett tillfälle – hur litet som helst – när du mådde lite bättre?",
                "Depression är en lögn som viskar att du alltid har känt så här och alltid kommer att göra det. Det stämmer inte. Vad är det allra minsta du kan göra idag för din kropp?"
            ]
            return responses.randomElement()!

        case .sömnproblem:
            return "Sömnproblem och psykisk ohälsa påverkar varandra i en ond cirkel. KBT-I (kognitiv beteendeterapi för insomni) är mer effektivt än sömntabletter på lång sikt. Vad är det som händer i huvudet när du lägger dig?"

        case .ensamhet:
            let responses = [
                "Ensamhet gör ont på ett djupt sätt – det är ett grundläggande mänskligt behov att höra hemma någonstans. Har du någon person i ditt liv – hur avlägsen som helst – som du kan skicka ett enda meddelande till idag?",
                "Ensamhet kan växa sig stor när vi isolerar oss, även om vi innerst inne längtar efter kontakt. Vad hindrar dig från att nå ut till någon just nu?"
            ]
            return responses.randomElement()!

        case .stress:
            let responses = [
                "Stress är kroppen och hjärnans sätt att signalera att något är i obalans. Ofta driver perfektionism och höga krav på oss själva på stressen. Vems röst hör du när du tänker på alla krav?",
                "Kronisk stress är utmattning i slow-motion. Av allt du bär just nu – vad är faktiskt ditt, och vad har du tagit på dig från andra?"
            ]
            return responses.randomElement()!

        case .ilska:
            let responses = [
                "Ilska är ofta en sekundär känsla – under den finns det nästan alltid en sårbarhet. Vad är det som egentligen gör dig så arg, vad kränktes?",
                "Ilska har en funktion: den säger att en gräns har överskridits. Vad behöver du som du inte får just nu?"
            ]
            return responses.randomElement()!

        case .skam:
            let responses = [
                "Skam är den mest smärtsamma känslan vi kan uppleva, för den säger att det är något fundamentalt fel på oss. Det är inte sant. Vad händer i kroppen när skammen kommer?",
                "Skam växer i mörker och vissnar i ljus. Du behöver inte förtjäna din plats i världen. Vad skulle du säga till en vän som kände precis som du gör nu?"
            ]
            return responses.randomElement()!

        case .relationer:
            let responses = [
                "Relationer är komplexa och kan trigga de djupaste sårorna. Vad är det viktigaste du vill bli förstådd för i den här relationen?",
                "I konflikter fokuserar vi ofta på vad den andra gör fel. Vad tror du att de behöver, bortom deras beteende?"
            ]
            return responses.randomElement()!

        case .motivation:
            let responses = [
                "Brist på motivation är ett klassiskt symptom på depression och utmattning – inte lathet. Beteendeaktivering visar att vi inte kan vänta på att känna oss motiverade; vi måste agera för att känslan ska följa. Vad är en sak, lika liten som att dricka ett glas vatten, som du kan göra nu?",
                "Fasthet i livet beror ofta på att vi väntar på att 'rätt feeling' ska komma. Men hjärnan lär sig ny motivation genom handling, inte tvärtom. Vad brukade ge dig glädje förut?"
            ]
            return responses.randomElement()!

        case .kris:
            return "Jag hör att du är i ett svårt läge just nu. Du behöver inte klara det här ensam. Finns det någon nära dig du kan kontakta? Om det känns akut, ring Självmordslinjen på 90101 – de finns dygnet runt."

        case .allmän:
            if isFollowUp {
                let followUps = [
                    "Det du delar är viktigt. Hur känns det i kroppen när du tänker på det?",
                    "Jag förstår. Vad tror du att den här känslan vill säga dig?",
                    "Tack för att du berättar. Vad behöver du mest just nu – att bli lyssnad på, eller att hitta ett nästa steg?",
                    "Du är modig som delar det här. Vad hade du velat att någon sade till dig just nu?"
                ]
                return followUps.randomElement()!
            }
            // Emotion-aware opening
            if emotion.dominant.value > 0.5 {
                return "Jag känner att du bär på \(emotion.dominant.name) just nu. Det är en viktig känsla att ta på allvar. Berätta mer – vad händer?"
            }
            let general = [
                "Välkommen hit – det är ett modigt steg att börja utforska hur du mår. Vad är det viktigaste du vill prata om idag?",
                "Jag är här och lyssnar utan att döma. Vad bär du på?",
                "Det finns inga fel svar här. Berätta vad som finns i dig just nu."
            ]
            return general.randomElement()!
        }
    }

    // MARK: - Dagboks-insikt

    static func diaryInsight(emotion: EmotionResult) -> String {
        let dom = emotion.dominant.name
        switch dom {
        case "sorg":
            return "I ditt inlägg ser jag en djup sorg. KBT påminner oss om att tankarna vi har om händelserna – inte händelserna i sig – skapar mest lidande. Vad är en alternativ tolkning av det som hänt?"
        case "ilska":
            return "Det jag läser här rymmer stark ilska, och ilska är ofta en signal om att något viktigt kränktes. Vad behöver du för att känna dig trygg och respekterad?"
        case "rädsla":
            return "Rädslan du beskriver är verklig och valid. KBT-tekniken 'beteendeexperiment' handlar om att testa om våra rädslor stämmer med verkligheten. Vad är det lilla testet du kan göra?"
        case "glädje":
            return "Det är fint att se glädje i dina ord! Kom ihåg att beteendeaktivering – alltså att göra mer av det som ger glädje – är ett av de starkaste skydden mot depression."
        default:
            return "Att skriva ner sina tankar och känslor är i sig ett kraftfullt KBT-verktyg. Lägg märke till de mönster som uppstår – vad återkommer? Vad kan du utmana?"
        }
    }

    // MARK: - Mood-insikter

    static func moodInsights(for entryDescription: String, emotion: EmotionResult, sentiment: Float) -> (summary: String, insights: [String], advice: [String]) {
        let domEmotion = emotion.dominant.name
        let moodLabel = sentiment > 0.2 ? "positiv" : sentiment < -0.2 ? "negativt laddad" : "neutral"

        // Bygg dynamisk sammanfattning baserad på känslan
        let summaryVariants: [String] = [
            "En \(moodLabel) dag dominerad av \(domEmotion). Dina registreringar hjälper dig se mönster du annars missar.",
            "Idag präglas av \(domEmotion). Att du loggar regelbundet bygger en värdefull bild av ditt mönster.",
            "Din dag verkar \(moodLabel) med \(domEmotion) som grundton. Varje loggning är ett steg mot självkännedom."
        ]
        let summary = summaryVariants.randomElement()!

        // Dynamiska insikter baserade på sentiment
        var insights: [String] = []
        if sentiment < -0.2 {
            insights.append("Dagar med lägre mående korrelerar ofta med sämre sömnkvalitet – håll koll på det sambandet.")
            insights.append("När mående dalar aktiveras ofta negativa tankemönster. KBT kallar det 'kognitiva förvrängningar'.")
        } else if sentiment > 0.2 {
            insights.append("Bra dagar beror sällan på tur – det finns konkreta beteenden bakom. Vad gjorde du idag som fungerade?")
            insights.append("Positiva dagar stärker din motståndskraft. Dokumentera vad som bidrog.")
        } else {
            insights.append("En neutral dag är inte en dålig dag – det är grundlinjen du kan bygga på.")
        }
        insights.append("Social kontakt, även kort, verkar ha positiv inverkan på ditt mående.")
        insights.append("\(domEmotion.capitalized) är en signal värd att utforska – vad utlöste den idag?")

        // Anpassade råd
        var advice: [String] = []
        if sentiment < -0.2 {
            advice.append("Prova 4-7-8-andningen i appen – tre rundor kan sänka ångesten märkbart.")
            advice.append("Beteendeaktivering: gör EN liten sak som brukade ge dig glädje, oavsett om du 'känner för det'.")
            advice.append("Ring eller skriv till en person du litar på – isolering förvärrar nedstämdhet.")
        } else {
            advice.append("Fortsätt med det som fungerade idag – det är beteendeaktivering i praktiken.")
            advice.append("Schemalägg det som gav dig energi idag igen i morgon – rutiner befäster framsteg.")
        }
        advice.append("En kort promenad (15-20 min) dagsljus kan stabilisera dygnsrytm och humör.")

        return (summary, Array(insights.prefix(4)), Array(advice.prefix(3)))
    }

    // MARK: - Veckorapport
    // Innovation 5: Dynamisk veckorapport.
    // Tar emot en strukturerad summary-sträng (format: "mood:0.6,anxiety:0.4,sleep:0.7,
    // outdoor:0.5,social:0.6,streak:4,logsCount:5") och genererar ett personaliserat
    // rapport-text baserat på faktiska värden istället för statisk boilerplate.

    static func weeklyReport(summary: String) -> String {
        // Parsa strukturerad summary om den innehåller nyckelord
        // Annars fall tillbaka till generisk rapport
        var mood:    Double = 0.5
        var anxiety: Double = 0.5
        var sleep:   Double = 0.5
        var outdoor: Double = 0.5
        var social:  Double = 0.5
        var streak:  Int    = 0
        var logs:    Int    = 0

        for part in summary.split(separator: ",") {
            let kv = part.split(separator: ":")
            guard kv.count == 2 else { continue }
            let key = String(kv[0]).trimmingCharacters(in: .whitespaces)
            let val = String(kv[1]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "mood":    mood    = Double(val) ?? 0.5
            case "anxiety": anxiety = Double(val) ?? 0.5
            case "sleep":   sleep   = Double(val) ?? 0.5
            case "outdoor": outdoor = Double(val) ?? 0.5
            case "social":  social  = Double(val) ?? 0.5
            case "streak":  streak  = Int(val)    ?? 0
            case "logsCount": logs  = Int(val)    ?? 0
            default: break
            }
        }

        // --- Dynamiska sektioner baserade på faktisk data ---

        // Humörtrend
        let moodPct = Int(mood * 100)
        let moodTrend: String
        if mood >= 0.7 {
            moodTrend = "Ditt genomsnittliga mående var \(moodPct)/100 – en riktigt bra vecka! Du verkar ha hittat något som fungerar."
        } else if mood >= 0.5 {
            moodTrend = "Ditt genomsnittliga mående var \(moodPct)/100 – en stabil vecka med potential att växa."
        } else {
            moodTrend = "Ditt genomsnittliga mående var \(moodPct)/100 – det verkar ha varit en tuff vecka. Det är okej, det är information, inte ett misslyckande."
        }

        // Sömn
        let sleepInsight: String
        if sleep >= 0.7 {
            sleepInsight = "Sömn: Du verkar ha sovit bra den här veckan – det skyddar direkt din psykiska hälsa."
        } else if sleep >= 0.45 {
            sleepInsight = "Sömn: Din sömn är godkänd men kan förbättras. Konsekvent läggningstid ±30 min är den enskilt effektivaste insatsen."
        } else {
            sleepInsight = "Sömn: Den här veckan verkar sömnen ha lidit. Dålig sömn förstärker ångest och nedstämdhet – det är ett prioriterat fokusområde."
        }

        // Ångest-kommentar
        let anxietyInsight: String
        if anxiety >= 0.65 {
            anxietyInsight = "Ångest: Du rapporterade förhöjd ångest den här veckan. KBT-tekniken exponering och beteendeexperiment kan hjälpa dig utmana undvikandet."
        } else {
            anxietyInsight = "Ångest: Din ångestnivå verkar ha legat på en hanterbar nivå – bra jobbat med att hantera det."
        }

        // Streak
        let streakText: String
        if streak >= 5 {
            streakText = "Loggningsstreak: \(streak) dagar i rad – det är imponerande! Kontinuitet är nyckeln till självkännedom."
        } else if streak >= 2 {
            streakText = "Loggningsstreak: \(streak) dagar. Bygg vidare på det här – varje dag du loggar stärker ditt självmedvetande."
        } else {
            streakText = logs > 0
                ? "Du loggade \(logs) gånger den här veckan – bra start! Sikta på daglig loggning nästa vecka."
                : "Du har inte loggat den här veckan. Kom ihåg: att logga regelbundet är i sig en KBT-intervention."
        }

        // Personaliserade fokusområden
        var focusAreas: [String] = []
        if sleep < 0.5  { focusAreas.append("Prioritera konsekvent sömntid – lägg dig och gå upp samma tid ±30 min") }
        if outdoor < 0.5 { focusAreas.append("Planera in minst 20 min utomhus varje dag – dagsljus reglerar dygnsrytm och humör") }
        if social < 0.5  { focusAreas.append("Nå ut till minst en person under veckan – även ett kort meddelande räknas") }
        if anxiety >= 0.65 { focusAreas.append("Prova daglig 4-7-8 andning: andas in 4s, håll 7s, ut 8s – tre rundor") }
        // Fyll upp till 3 om för få
        if focusAreas.count < 2 { focusAreas.append("Lägg till en beteendeaktiveringsövning om dagen – gör något litet som brukade ge glädje") }
        if focusAreas.count < 3 { focusAreas.append("Skriv tre saker du är tacksam för varje kväll – tränar hjärnan att se det positiva") }

        let focusList = focusAreas.prefix(3).enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        return """
        Veckosammanfattning från Lilla Jag

        \(moodTrend)

        \(sleepInsight)
        \(anxietyInsight)
        \(streakText)

        Tre fokusområden nästa vecka:
        \(focusList)

        Mikromål:
        • Logga mående varje morgon – inte bara när det är tungt
        • En kort promenad (15–20 min) dagsljus varje dag
        • Prata med KBT-assistenten om det som är svårt just nu
        """
    }

    // MARK: - Groundingövning (krisplan)

    static func groundingExercise() -> String {
        let exercises = [
            "5-4-3-2-1 övning: Nämn 5 saker du ser, 4 du kan röra, 3 du hör, 2 du kan lukta och 1 du smakar. Det landar ditt nervsystem i nuet.",
            "Håll en isbit i handen i 30 sekunder. Fokusera helt på kylan. Din hjärna kan inte hantera panik och stark sensorisk input samtidigt.",
            "Andas in 4 sekunder, håll 7 sekunder, andas ut 8 sekunder. Tre rundor. Vagusnerven aktiveras och sänker stressnivån.",
            "Tryck fötterna hårt mot golvet. Känn marken under dig. Rör tårna, en i taget. Du är här. Du är trygg just nu.",
            "Sätt på kallt vatten på handlederna i 30 sekunder. Det aktiverar dykningsreflexen och lugnar kroppen direkt."
        ]
        return exercises.randomElement()!
    }

    // MARK: - Copingförslag (krisplan)

    static func copingSuggestions(for emotion: EmotionResult) -> [String] {
        let dom = emotion.dominant.name
        switch dom {
        case "rädsla":
            return [
                "Prova progressiv muskelavslappning – spänn och slappna av varje muskelgrupp i 5 sekunder",
                "Gå ut i frisk luft – rörelse och syre bryter ångestcykeln",
                "Ring en trygg person och berätta hur du mår"
            ]
        case "sorg":
            return [
                "Skriv ner tre saker du är tacksam för – hjärnan kan inte vara nedstämd och tacksam samtidigt",
                "Gör en liten sak som brukade ge dig glädje, även om du inte känner för det",
                "Kontakta någon du litar på – isolering förvärrar nedstämdhet"
            ]
        case "ilska":
            return [
                "Fysisk rörelse – spring, gå snabbt, gör armhävningar – kanalisera energin",
                "Skriv ner vad du känner utan censur, riv sedan sönder pappret",
                "Räkna långsamt till 10 med djupa andetag mellan varje tal"
            ]
        default:
            return [
                "Prova 4-7-8 andningen: andas in 4s, håll 7s, ut 8s",
                "Gå ut i naturen 15 minuter – dagsljus stabiliserar humöret",
                "Ring eller skriv till någon du bryr dig om"
            ]
        }
    }

    // MARK: - Församtalsstöd (krisnummer)

    static func preCallGrounding() -> String {
        let tips = [
            "Du behöver inte ha färdiga ord. Personen som svarar är utbildad att lyssna. Börja med 'Jag mår inte bra' – det räcker.",
            "Det är modigt att ringa. Du behöver inte förklara allt. Säg bara det du orkar. De förstår.",
            "Andas lugnt innan du ringer. Du förtjänar stöd. Det finns ingen skam i att be om hjälp.",
            "Innan du ringer: ta tre djupa andetag. Påminn dig att samtalet är anonymt och kostnadsfritt. Du gör rätt som ringer."
        ]
        return tips.randomElement()!
    }

    // MARK: - Socialt stöd

    static func socialEncouragement(sentiment: Float) -> String {
        if sentiment < -0.2 {
            return "Ensamhet kan kännas överväldigande, men forskning visar att redan en kort kontakt – ett meddelande, ett samtal – kan bryta den negativa spiralen. Du behöver inte prestera socialt. Bara att finnas räcker."
        } else if sentiment > 0.2 {
            return "Du verkar ha bra energi just nu – perfekt tillfälle att nå ut till någon. Social kontakt förstärker positiva känslor och bygger motståndskraft för tuffare dagar."
        } else {
            return "Mänsklig kontakt är grundläggande för psykisk hälsa. Även digital kontakt räknas. Vem kan du skicka ett 'hej' till idag?"
        }
    }

    // MARK: - Donationsmotivation

    static func donationMotivation() -> String {
        let texts = [
            "Att hjälpa andra aktiverar hjärnans belöningssystem – du mår bättre av att ge. Forskning visar att altruism stärker den egna psykiska hälsan.",
            "Varje krona till psykisk hälsa kan rädda liv. Självmordslinjen svarar på 200 000+ samtal per år. Din insats gör skillnad.",
            "Genom att dela appen hjälper du någon som kämpar i tystnad. Det kan vara det viktigaste du gör idag.",
            "Forskning visar att hjälpbeteende ökar välmående och minskar stress. Att ge tillbaka är en investering i din egen hälsa."
        ]
        return texts.randomElement()!
    }

    // MARK: - Monster-insikt

    static func monsterInsight(log: DailyLog, emotion: EmotionResult, sentiment: Float) -> String {
        let scores = [log.sleep, log.meals, log.outdoor, log.exercise, log.social]
        let avg = Double(scores.reduce(0, +)) / Double(scores.count)

        if avg >= 3.0 {
            return "Monstret ser att du tar hand om dig idag – det gör monstret starkt och glad! Fortsätt med det som fungerar."
        } else if avg >= 2.0 {
            let areas = [("sömnen", log.sleep), ("maten", log.meals), ("utomhustiden", log.outdoor),
                         ("träningen", log.exercise), ("det sociala", log.social)]
            let weak = areas.filter { $0.1 < 3 }.map { $0.0 }
            return "Monstret ser att du gör ditt bästa. Imorgon kan du satsa lite extra på \(weak.joined(separator: " och ")) – små steg gör stor skillnad!"
        } else {
            return "Monstret vill krama dig. Tuffa dagar händer alla. Att du loggade visar att du bryr dig om dig själv – det är modigt."
        }
    }

    // MARK: - Hjälp

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

// MARK: - Konversationsstartare

enum ConversationStarter: String, CaseIterable {
    case ångest       = "Jag är orolig och vet inte varför"
    case nedstämdhet  = "Jag känner mig hopplös"
    case sömnproblem  = "Jag sover väldigt dåligt"
    case ensamhet     = "Jag känner mig ensam"
    case stress       = "Jag är stressad och överväldigad"
    case tankar       = "Jag har negativa tankar om mig själv"
    case krisplan     = "Jag mår akut dåligt"

    var icon: String {
        switch self {
        case .ångest:      return "wind"
        case .nedstämdhet: return "cloud.rain.fill"
        case .sömnproblem: return "moon.fill"
        case .ensamhet:    return "person.fill"
        case .stress:      return "bolt.fill"
        case .tankar:      return "thought.bubble"
        case .krisplan:    return "cross.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .ångest:      return Color.warmLavender
        case .nedstämdhet: return Color(hex: 0x6B8DD6)
        case .sömnproblem: return Color(hex: 0x9B8ED6)
        case .ensamhet:    return Color.warmRose
        case .stress:      return Color.warmGold
        case .tankar:      return Color.warmSage
        case .krisplan:    return Color(hex: 0xFF5B5B)
        }
    }
}
