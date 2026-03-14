// Config.swift
// Lilla Jag – Konfiguration
//
// Appen kör all AI lokalt via Qwen3 1.7B / llama.cpp + Metal.
// Inga molnberoenden eller API-nycklar krävs.

import Foundation

enum Config {
    // MARK: - Lokal AI (Qwen via llama.cpp)

    /// Namn på GGUF-modellfilen i app-bunten.
    /// Lägg till i Xcode: File ▸ Add Files to Project → lägg som Bundle Resource
    /// Modell: Qwen3-1.7B-Q4_K_M.gguf (~1 GB) – körs lokalt via llama.cpp + Metal
    static let qwenModelFilename = "Qwen3-1.7B-Q4_K_M.gguf"

    /// Max antal tokens i svar
    static let maxResponseTokens = 512

    /// Kontextlängd (tokens) – 2048 fungerar bra på iPhone 14+
    static let contextLength = 2048

    // MARK: - App

    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let appName = "Lilla Jag"

    // MARK: - Bakåtkompatibilitet (molntjänster borttagna)
    // Alla molntjänster är ersatta med lokal AI.
    // Behålls tomma för att undvika kompileringsfel i äldre kod.
    static var openAIAPIKey: String { "" }
}
