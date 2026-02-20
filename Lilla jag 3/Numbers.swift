//
//  Numbers.swift
//  Lilla Jag
//
//  Omdesign 14 aug 2025 av ChatGPT (GPT-5 Thinking)
//  – Supersnygg glas/gradient-design med snabbåtkomst & bekräftad uppringning
//

import SwiftUI

// MARK: – Modell
private struct EmergencyNumber: Identifiable, Equatable {
    let id = UUID()
    let number: String
    let raw: String          // Endast siffror för tel://
    let description: String
    
    var url: URL {
        URL(string: "tel://\(raw.replacingOccurrences(of: " ", with: ""))")!
    }
}

// MARK: – Huvudvy
struct NumbersView: View {
    @Environment(\.openURL) private var openURL
    @State private var toCall: EmergencyNumber?
    @State private var showConfirm = false
    
    // Accent-gradient för rubriker/indikator
    private let accent = LinearGradient(
        colors: [Color(#colorLiteral(red: 0.996, green: 0.345, blue: 0.655, alpha: 1)),
                 Color(#colorLiteral(red: 0.627, green: 0.431, blue: 0.976, alpha: 1)),
                 Color(#colorLiteral(red: 0.251, green: 0.596, blue: 0.976, alpha: 1))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Utökad lista med nationella akuta- och stödnummer.
    private let data: [EmergencyNumber] = [
        .init(number: "112",          raw: "112",        description: "Akut larm – polis, räddningstjänst, ambulans"),
        .init(number: "1177",         raw: "1177",       description: "Sjukvårdsrådgivning dygnet runt"),
        .init(number: "113 13",       raw: "11313",      description: "Krisinformation vid olyckor & stora händelser"),
        .init(number: "114 14",       raw: "11414",      description: "Polisärenden som inte är akuta"),
        .init(number: "116 000",      raw: "116000",     description: "SOS Alarm – försvunna barn"),
        .init(number: "116 006",      raw: "116006",     description: "Brottsofferjouren – stöd till brottsutsatta"),
        .init(number: "116 016",      raw: "116016",     description: "Kvinnofridslinjen – stöd vid hot & våld"),
        .init(number: "116 111",      raw: "116111",     description: "BRIS – stödlinje för barn & unga"),
        .init(number: "90390",        raw: "90390",      description: "Hjälplinjen – stöd vid psykisk ohälsa"),
        .init(number: "90 101",       raw: "90101",      description: "Självmordslinjen (Mind) – dygnet runt"),
        .init(number: "020-22 00 60", raw: "020220060",  description: "Jourhavande medmänniska – kväll & natt"),
        .init(number: "020-22 22 33", raw: "020222233",  description: "Äldrelinjen – stöd för 65+"),
        .init(number: "020-85 20 00", raw: "020852000",  description: "Föräldralinjen – råd till föräldrar"),
        .init(number: "020-84 44 48", raw: "020844448",  description: "Alkohollinjen – förändra alkoholvanor"),
        .init(number: "020-91 91 91", raw: "020919191",  description: "Droghjälpen – frågor om droger"),
        .init(number: "020-84 00 00", raw: "020840000",  description: "Sluta-Röka-Linjen – stöd att sluta röka/snusa"),
        .init(number: "020-81 91 00", raw: "020819100",  description: "Stödlinjen – spel om pengar"),
        .init(number: "020-57 70 70", raw: "020577070",  description: "Rätt att välja – hedersrelaterat stöd"),
        .init(number: "020-80 80 80", raw: "020808080",  description: "Stödlinjen för män – utsatta för våld"),
        .init(number: "020-66 77 88", raw: "020667788",  description: "PrevenTell – oönskad sexualitet"),
        .init(number: "020-555 666",  raw: "020555666",  description: "Välj att sluta – få hjälp att stoppa våld"),
        .init(number: "0200-239 500", raw: "0200239500", description: "Anhöriglinjen – stöd till närstående"),
        .init(number: "020-18 18 00", raw: "020181800",  description: "SPES – stöd för efterlevande vid suicid"),
        .init(number: "08-30 30 20",  raw: "08303020",   description: "Mansjouren – samtalsstöd för män"),
        .init(number: "08-37 43 00",  raw: "08374300",   description: "Spelfrihetens helpline – spelberoende")
    ]
    
    // Hjälp för att hämta visst nummer
    private func num(_ rawOnlyDigits: String) -> EmergencyNumber? {
        data.first { $0.raw == rawOnlyDigits }
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    
                    // MARK: – Rubrik
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hjälp & Nödnummer")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
                        Text("Snabb åtkomst till akuta larm och stödlinjer")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                    
                    // MARK: – Hero-panel (inspiration från din bild)
                    GlassPanel {
                        VStack(spacing: 14) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 38, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.green, .white)
                                .shadow(radius: 6)
                                .accessibilityHidden(true)
                            
                            Text("Vi finns här")
                                .font(.title2.weight(.semibold))
                            Text("Välj en snabbåtgärd eller bläddra bland alla nummer nedan.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 12) {
                                if let n112 = num("112") {
                                    GradientButton(title: "Ring 112", systemImage: "phone.fill.arrow.up.right", style: .danger) {
                                        toCall = n112
                                        showConfirm = true
                                    }
                                    .accessibilityLabel("Ring ett akut larm 112")
                                }
                                if let n1177 = num("1177") {
                                    GradientButton(title: "1177 Råd", systemImage: "stethoscope", style: .primary) {
                                        toCall = n1177
                                        showConfirm = true
                                    }
                                    .accessibilityLabel("Ring 1177 sjukvårdsrådgivning")
                                }
                            }
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // MARK: – Snabbkort (viktiga linjer)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                        GridItem(.flexible(), spacing: 14)],
                              spacing: 14) {
                        QuickTile(icon: "shield.fill",
                                  title: "114 14",
                                  subtitle: "Polis – ej akut",
                                  color: .blue.opacity(0.6)) {
                            if let n = num("11414") { toCall = n; showConfirm = true }
                        }
                        QuickTile(icon: "exclamationmark.bubble.fill",
                                  title: "113 13",
                                  subtitle: "Krisinformation",
                                  color: .yellow.opacity(0.55)) {
                            if let n = num("11313") { toCall = n; showConfirm = true }
                        }
                        QuickTile(icon: "figure.and.child.holdinghands",
                                  title: "116 111",
                                  subtitle: "BRIS – barn & unga",
                                  color: .mint.opacity(0.6)) {
                            if let n = num("116111") { toCall = n; showConfirm = true }
                        }
                        QuickTile(icon: "heart.text.square.fill",
                                  title: "90 101",
                                  subtitle: "Självmordslinjen",
                                  color: .red.opacity(0.55)) {
                            if let n = num("90101") { toCall = n; showConfirm = true }
                        }
                    }
                    
                    // MARK: – Alla nummer (glaslista)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Alla nummer")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 2)
                        
                        LazyVStack(spacing: 14) {
                            ForEach(data) { item in
                                GlassRow {
                                    HStack(spacing: 14) {
                                        Capsule()
                                            .fill(accent)
                                            .frame(width: 6, height: 30)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.number)
                                                .font(.title3.weight(.semibold))
                                            Text(item.description)
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        
                                        Spacer(minLength: 8)
                                        
                                        Button {
                                            toCall = item
                                            showConfirm = true
                                        } label: {
                                            Image(systemName: "phone.fill")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                                .padding(10)
                                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Ring \(item.number)")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 120)   // Utrymme för safe area
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(GlassyBackground()
                .frame(width: geo.size.width, height: geo.size.height)
                .ignoresSafeArea()
            )
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 16)
            }
        }
        .navigationTitle("Nödnummer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    ContentView()
                        .navigationBarBackButtonHidden(true)
                } label: {
                    Image(systemName: "house.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.25),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog(
            toCall?.number ?? "",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            if let item = toCall {
                Button("Ring \(item.number)", role: .destructive) {
                    openURL(item.url)
                }
            }
            Button("Avbryt", role: .cancel) { }
        } message: {
            if let item = toCall {
                Text(item.description)
            }
        }
    }
}

// MARK: – Glasiga byggblock

/// Stor panel i glas-stil (liknar din inloggningskort-design)
private struct GlassPanel<Content: View>: View {
    let content: () -> Content
    var body: some View {
        content()
            .padding(.vertical, 20)
            .padding(.horizontal, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 12)
    }
}

/// Mindre rad/kort i glas-stil
private struct GlassRow<Content: View>: View {
    let content: () -> Content
    var body: some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 8)
    }
}

/// Gradient-knappar i tre stilar
private struct GradientButton: View {
    enum Style { case primary, danger, neutral }
    let title: String
    let systemImage: String
    var style: Style = .primary
    var action: () -> Void
    
    private var gradient: LinearGradient {
        switch style {
        case .primary:
            return LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .danger:
            return LinearGradient(colors: [Color.red, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .neutral:
            return LinearGradient(colors: [.gray.opacity(0.7), .gray.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// Snabbkort (2-kolumners)
private struct QuickTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = .blue.opacity(0.6)
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.bold())
                    .frame(width: 36, height: 36)
                    .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Bakgrund (mjuk, glödande gradient med ljusblobbar)
private struct GlassyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(#colorLiteral(red: 0.06, green: 0.07, blue: 0.12, alpha: 1)),
                         Color(#colorLiteral(red: 0.05, green: 0.07, blue: 0.18, alpha: 1))],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(colors: [Color.purple.opacity(0.35), .clear],
                           center: .topLeading, startRadius: 20, endRadius: 500)
                .offset(x: -80, y: -120)
            RadialGradient(colors: [Color.blue.opacity(0.40), .clear],
                           center: .bottomTrailing, startRadius: 30, endRadius: 520)
                .offset(x: 100, y: 160)
            RadialGradient(colors: [Color.pink.opacity(0.35), .clear],
                           center: .center, startRadius: 10, endRadius: 420)
                .offset(x: -30, y: 40)
        }
    }
}

// MARK: – Förhandsvisning
#Preview {
    NavigationStack {
        NumbersView()
            .preferredColorScheme(.dark)
    }
}
