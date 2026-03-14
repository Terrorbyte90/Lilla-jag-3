// LillaJagColors.swift
// Lilla Jag – Global färgdefinitioner

import SwiftUI

// MARK: - Color hex initializer

extension Color {
    /// Skapa en Color från ett hexvärde, t.ex. Color(hex: 0xFF6B8A)
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Semantiska appfärger

extension Color {
    // Varma, lugnande toner – ej kliniskt kalla
    static let warmRose     = Color(hex: 0xFF6B8A)  // kärlek, omsorg
    static let warmLavender = Color(hex: 0xBB86FC)  // lugn, AI/hjärna
    static let warmSage     = Color(hex: 0x7EC8A4)  // natur, framsteg
    static let warmGold     = Color(hex: 0xFFD166)  // energi, belöning
    static let warmCoral    = Color(hex: 0xFF8C69)  // aktivitet, handling
}
