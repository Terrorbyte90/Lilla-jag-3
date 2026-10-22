// CrisisDetector.swift
// Lilla Jag – Gemensam krisdetektion
//
// Körs på ALLA användarmeddelanden innan någon AI (Qwen eller KBTFallback)
// får svara, så att en hänvisning till Självmordslinjen alltid garanteras.
// Matchar hela ord/fraser – "dö" ska inte trigga på "dörr" eller "döttrar".

import Foundation

enum CrisisDetector {

    /// Fraser som tyder på självmordstankar eller självskada.
    static let phrases: [String] = [
        "suicid", "självmord", "ta livet av mig", "ta mitt liv", "ta mitt eget liv",
        "vill dö", "vill bara dö", "vill inte leva", "inte leva längre", "orkar inte leva",
        "döda mig", "dödar mig", "skada mig själv", "skada mig", "självskad",
        "skära mig", "skär mig", "vill försvinna", "bara försvinna", "inte vill finnas", "vill inte finnas",
        "slippa leva", "avsluta allt", "göra slut på allt", "göra slut på mig",
        "orkar inte mer", "ingen mening att leva", "bättre utan mig", "hoppa framför",
        "överdos", "hänga mig"
    ]

    /// Enstaka ord som bara räknas när de står som egna ord.
    static let words: Set<String> = ["dö", "hopplöst", "hopplös"]

    static func isCrisis(_ text: String) -> Bool {
        let lower = text.lowercased()
        if phrases.contains(where: { lower.contains($0) }) { return true }
        let tokens = lower.components(separatedBy: CharacterSet.letters.inverted)
        return tokens.contains { words.contains($0) }
    }

    /// Svar som alltid ges i krisläge – oberoende av AI-modell.
    static let response = """
    Det låter som du har det väldigt tungt just nu, och jag vill att du vet att du inte är ensam. \
    Ring Självmordslinjen på 90101 eller chatta via mind.se – de finns dygnet runt och lyssnar utan att döma. \
    Är du i omedelbar fara, ring 112. Kan du ringa någon av dem nu?
    """
}
