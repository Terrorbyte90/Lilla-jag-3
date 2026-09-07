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
    
    // Premium Fable-5 färger
    static let ljAccentPurple = Color(hex: 0xC084FC)  // starkare lavendel
    static let ljAccentPink   = Color(hex: 0xF472B6)  // starkare ros
    static let ljDeepPurple   = Color(hex: 0x7C3AED)  // djup lila
    static let ljNightBlue    = Color(hex: 0x3B82F6)  // nattlig blå
    static let ljAuroraCyan   = Color(hex: 0x22D3EE)  // aurora cyan
    static let ljSunsetOrange = Color(hex: 0xFB923C)  // solnedgång orange
    
    // Premium gradients för Fable-5
    static var ljAuroraGradient: LinearGradient {
        LinearGradient(
            colors: [warmLavender, warmRose, warmGold],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var ljNightGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x1A1025), Color(hex: 0x2D1F4E)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var ljAccentGradient: LinearGradient {
        LinearGradient(
            colors: [warmLavender, ljAccentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
