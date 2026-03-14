// Config.swift
// Lilla Jag – Konfiguration
//
// Appen kör all AI lokalt via Qwen/llama.cpp.
// Inga molnberoenden eller API-nycklar krävs.

import Foundation

enum Config {
    // MARK: - Lokal AI (Qwen via llama.cpp)

    /// Namn på GGUF-modellfilen i app-bunten.
    /// Lägg till i Xcode: File ▸ Add Files to Project (ej kopiera, lägg som Bundle Resource)
    /// Rekommenderad modell: qwen2.5-1.5b-instruct-q4_k_m.gguf (~1 GB)
    /// Ladda ned: https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF
    static let qwenModelFilename = "qwen2.5-1.5b-instruct-q4_k_m.gguf"

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
