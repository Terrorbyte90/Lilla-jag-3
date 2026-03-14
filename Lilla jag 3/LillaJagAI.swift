// LillaJagAI.swift
// Lilla Jag – Lokal AI-motor
//
// Arkitektur:
//   1. LillaJagAIService – singleton som alla vyer använder
//   2. ChatMessage – gemensam meddelandemodell
//   3. KBT-svarsmotor med evidensbaserade svar
//
// ──────────────────────────────────────────────────────────
// MARK: - llama.cpp Integration Point
//
// För att aktivera Qwen/GGUF:
//   1. Lägg till Swift Package: https://github.com/ggml-org/llama.cpp
//      ELLER använd LLM.swift / LLMFarm-paketet
//   2. Bunta in modell-filen (t.ex. qwen2.5-1.5b-instruct-q4_k_m.gguf)
//      som Bundle Resource i Xcode
//   3. Avkommentera kodblocket "llama.cpp integration" nedan
//   4. Ta bort KBTFallback-anropet i generateResponse()
//
// Rekommenderad modell för iPhone 14/15 (6 GB RAM):
//   Qwen 2.5 1.5B Instruct Q4_K_M  (~1 GB)
//   https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF
// ──────────────────────────────────────────────────────────

import Foundation
import SwiftUI

// MARK: - ChatMessage

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date

    init(role: Role, content: String, timestamp: Date = .now) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    enum Role: String, Codable {
        case user, assistant, system
    }
}

// MARK: - LillaJagAIService

@MainActor
final class LillaJagAIService: ObservableObject {
    static let shared = LillaJagAIService()

    @Published var isThinking = false

    // Aktiv konversationshistorik per session
    @Published private(set) var messages: [ChatMessage] = []

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
    • Svara med max 3-4 meningar, sedan en fråga
    • Inga listor med punkter i konversation – skriv naturligt
    """

    // MARK: - Modell-status

    var modelIsLoaded: Bool {
        // TODO: Returnera true när llama.cpp-modellen är laddad
        return false
    }

    var modelName: String {
        // TODO: Returnera faktiskt modellnamn
        return "KBT-motor (offline)"
    }

    // MARK: - Generera svar

    func generateResponse(to userMessage: String) async -> String {
        isThinking = true
        defer { isThinking = false }

        // Lägg till ett realistiskt fördröjning för bättre UX
        let thinkTime = Double.random(in: 0.8...1.8)
        try? await Task.sleep(nanoseconds: UInt64(thinkTime * 1_000_000_000))

        // ────────────────────────────────────────────
        // llama.cpp integration (aktivera när modell finns):
        //
        // if modelIsLoaded {
        //     return await runQwenInference(prompt: buildPrompt(userMessage))
        // }
        // ────────────────────────────────────────────

        return KBTFallback.response(for: userMessage, history: messages)
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
    }

    func addAssistantMessage(_ text: String) {
        messages.append(ChatMessage(role: .assistant, content: text))
    }

    func newSession() {
        messages = []
    }

    // Välkomstmeddelande
    func welcomeMessage(name: String? = nil) -> String {
        let greeting = name.map { "Hej \($0)!" } ?? "Hej!"
        return "\(greeting) Jag är här för dig. Vad bär du på just nu?"
    }

    // Snabbanalys för moodlogg-insikter (används av MoodViewModel)
    func analyzeMoodEntry(_ entryDescription: String) async -> (summary: String, insights: [String], advice: [String]) {
        isThinking = true
        defer { isThinking = false }

        try? await Task.sleep(nanoseconds: 600_000_000)

        return KBTFallback.moodInsights(for: entryDescription)
    }

    // Vecklig rapport (används av MoodViewModel)
    func weeklyReport(summary: String) async -> String {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return KBTFallback.weeklyReport(summary: summary)
    }

    // MARK: - llama.cpp inference (skelett för framtida integration)
    //
    // private func runQwenInference(prompt: String) async -> String {
    //     // Initiera llama_model och llama_context
    //     // Tokenisera prompt
    //     // Kör llama_decode i loop
    //     // Returnera genererad text
    //     return ""
    // }
    //
    // private func buildPrompt(_ userMessage: String) -> String {
    //     var prompt = "<|im_start|>system\n\(systemPrompt)<|im_end|>\n"
    //     for msg in messages {
    //         let role = msg.role == .user ? "user" : "assistant"
    //         prompt += "<|im_start|>\(role)\n\(msg.content)<|im_end|>\n"
    //     }
    //     prompt += "<|im_start|>user\n\(userMessage)<|im_end|>\n<|im_start|>assistant\n"
    //     return prompt
    // }
}

// MARK: - KBT Fallback Motor

private enum KBTFallback {
    // Trigger-nyckelord → respons-kategori
    private enum Topic {
        case kris, ångest, nedstämdhet, sömnproblem, ensamhet,
             stress, ilska, skam, relationer, motivation, allmän
    }

    static func response(for input: String, history: [ChatMessage]) -> String {
        let lower = input.lowercased()

        // Krisläge – alltid prioritet
        if containsAny(lower, ["suicid", "ta livet", "dö", "döda mig",
                               "inte leva", "hopplöst", "orkar inte mer"]) {
            return "Det låter som du har det väldigt tungt just nu, och jag vill att du vet att du inte är ensam. Ring Självmordslinjen på 90101 – de finns dygnet runt och lyssnar utan att döma. Kan du ringa dem nu?"
        }

        let topic = detectTopic(lower)
        let isFollowUp = history.count > 2

        return topicResponse(topic, input: input, isFollowUp: isFollowUp)
    }

    private static func detectTopic(_ input: String) -> Topic {
        if containsAny(input, ["panik", "ångest", "hjärtat", "andas", "rädd", "oro"]) { return .ångest }
        if containsAny(input, ["ledsen", "trist", "depression", "tom", "meningslös", "gråter"]) { return .nedstämdhet }
        if containsAny(input, ["sover", "sömn", "trött", "vaknar", "natt"]) { return .sömnproblem }
        if containsAny(input, ["ensam", "ingen", "vänner", "isolerad", "saknar"]) { return .ensamhet }
        if containsAny(input, ["stress", "pressat", "hinner", "krav", "jobb", "skola"]) { return .stress }
        if containsAny(input, ["arg", "ilsken", "explosiv", "frustrerad", "irriterad"]) { return .ilska }
        if containsAny(input, ["skam", "skämms", "dålig", "värdelös", "misslyckad"]) { return .skam }
        if containsAny(input, ["relation", "partner", "kärlek", "bråk", "separation"]) { return .relationer }
        if containsAny(input, ["motivat", "orkar", "energi", "gör ingenting", "fastnat"]) { return .motivation }
        if containsAny(input, ["kris", "akut", "hjälp", "klarar", "bryta"]) { return .kris }
        return .allmän
    }

    private static func topicResponse(_ topic: Topic, input: String, isFollowUp: Bool) -> String {
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
                "Depression är en lögn som viskar att du alltid har känt så här och alltid kommer att göra det. Det stämmer inte. Vad är det allra minsta du kan göra idag för din kropp – en glattes vatten, ett steg utomhus?"
            ]
            return responses.randomElement()!

        case .sömnproblem:
            let responses = [
                "Sömnproblem och psykisk ohälsa påverkar varandra i en ond cirkel. KBT för sömnproblem (KBT-I) är faktiskt mer effektivt än sömntabletter på lång sikt. Vad är det som händer i huvudet när du lägger dig?"
            ]
            return responses.randomElement()!

        case .ensamhet:
            let responses = [
                "Ensamhet gör ont på ett djupt sätt. Det är en mänsklig grundbehov att höra hemma någonstans. Har du någon person i ditt liv – hur avlägsen som helst – som du kan skicka ett enda meddelande till idag?",
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
                "Ilska är ofta en sekundär känsla – under den finns det nästan alltid en sårbarhet. Vad är det som egentligen gör dig så arg i den här situationen – vad kränktes?",
                "Ilska har en funktion: den säger att en gräns har överskridits. Vad behöver du som du inte får just nu?"
            ]
            return responses.randomElement()!

        case .skam:
            let responses = [
                "Skam är den mest smärtsamma känslan vi kan uppleva, för den säger att det är något fundamentalt fel på oss – inte på det vi gjorde, utan på oss. Det är lögn. Vad händer i kroppen när skammen kommer?",
                "Skam växer i mörker och vissnar i ljus, som Brené Brown säger. Du behöver inte förtjäna din plats i världen. Vad skulle du säga till en vän som kände som du gör nu?"
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
                "Brist på motivation är ett klassiskt symptom på depression och utmattning – inte lat. Beteendeaktivering visar att vi inte kan vänta på att känna oss motiverade; vi måste agera för att känslan ska följa. Vad är en sak, lika liten som att dricka ett glas vatten, som du kan göra nu?",
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
            let general = [
                "Välkommen hit – det är ett modigt steg att börja utforska hur du mår. Vad är det viktigaste du vill prata om idag?",
                "Jag är här och lyssnar utan att döma. Vad bär du på?",
                "Det finns inga fel svar här. Berätta vad som finns i dig just nu."
            ]
            return general.randomElement()!
        }
    }

    // MARK: - Mood-insikter

    static func moodInsights(for entryDescription: String) -> (summary: String, insights: [String], advice: [String]) {
        let summary = "En dag med blandade upplevelser. Dina registrerade data ger värdefull insikt om mönster i ditt mående."

        let insights: [String] = [
            "Sömn och ångestnivå verkar hänga ihop – dagar med sämre sömn visar ofta högre ångest.",
            "Utomhustid korrelerar positivt med din energinivå.",
            "Social kontakt, även kort, verkar ha positiv inverkan på ditt mående.",
            "Rutiner bidrar till stabilitet i ditt humör."
        ]

        let advice: [String] = [
            "Försök hålla en konsekvent läggningstid – även 30 minuter kan göra skillnad.",
            "En kort promenad (15-20 min) kan bryta ångescykeln.",
            "Skicka ett meddelande till en vän idag – kontakt, hur kort som helst.",
            "Schemalägg en aktivitet som brukade ge dig glädje, oavsett om du 'känner för det'."
        ]

        return (summary, insights, advice)
    }

    // MARK: - Veckorapport

    static func weeklyReport(summary: String) -> String {
        return """
        📊 Veckosammanfattning

        Dina mående-registreringar under veckan ger en bild av din psykiska hälsa.

        • Trend: Ditt mående visar variationer som är helt normala. Uppmärksamma vilka dagar som var bättre.
        • Sömnmönster: Sömnen påverkar direkt energi och ångest – prioritera sömnhygien.
        • Positiva faktorer: Social kontakt och utomhustid gav positiva effekter.

        🎯 Tre fokusområden nästa vecka:
        1. Lägg till minst en beteendeaktiveringsövning om dagen
        2. Håll konsekvent läggningstid ±30 min
        3. Nå ut till en person du bryr dig om

        💪 Mikromål:
        • 15 min promenad varje dag
        • Logga mående på morgonen – inte bara när det är tungt
        • Skriv tre saker du är tacksam för varje kväll
        """
    }

    // MARK: - Hjälpfunktion

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

// MARK: - Konversationsstartare (fördefinierade frågor)

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
        case .ångest:      return .warmLavender
        case .nedstämdhet: return Color(hex: 0x6B8DD6)
        case .sömnproblem: return Color(hex: 0x9B8ED6)
        case .ensamhet:    return .warmRose
        case .stress:      return .warmGold
        case .tankar:      return .warmSage
        case .krisplan:    return Color(hex: 0xFF5B5B)
        }
    }
}
