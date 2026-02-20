import SwiftUI
import Foundation
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: – Huvudvy
struct KrisplanView: View {
    @StateObject private var store       = KrisplanStore()
    @State private var laddar            = false
    @State private var alertText         = ""
    @State private var visaAlert         = false
    @State private var visaHem           = false
    private let assistant                = GPTAssistant()

    // Centrala mått
    private let knappHöjd: CGFloat       = 52
    private let knappMellanrum: CGFloat  = 10
    private let minFältHöjd: CGFloat     = 90

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroKort
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                        VStack(spacing: 18) {
                            fält
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        // Extra bottenmarginal för nederpanelen i safe area
                        .padding(.bottom, 160)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(.horizontal, 16)

            if laddar {
                ProgressView("ChatGPT tänker …")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
            }
        }
        .foregroundStyle(.white)
        .onAppear { store.startMolnInit() }
        .overlay(
            Group {
                if visaAlert {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(1)
                    VStack(spacing: 0) {
                        VStack(spacing: 18) {
                            Text("Tips från ChatGPT")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ScrollView {
                                Text(alertText)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 2)
                            }
                            .frame(maxHeight: 380)
                        }
                        .padding(.top, 22)
                        .padding(.horizontal, 22)
                        Button(action: { withAnimation { visaAlert = false } }) {
                            Text("Stäng")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: knappHöjd)
                                .background(
                                    LinearGradient(colors: [.blue, .purple],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing)
                                        .opacity(0.95)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.white.opacity(0.25), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)
                    .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
                    .transition(.scale)
                    .zIndex(2)
                }
            }
        )
        .safeAreaInset(edge: .bottom) {
            nederPanel
                .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $visaHem) {
            ContentView()
                .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: – Hero-kort
    private var heroKort: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 72, height: 72)
                    .blur(radius: 6)
                    .offset(y: 2)

                Circle()
                    .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Image(systemName: "heart.text.square.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                            .font(.system(size: 26, weight: .bold))
                    )
                    .shadow(color: .green.opacity(0.5), radius: 16, y: 8)
            }

            Text("Min Krisplan")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)

            Text("En trygg väg ut ur krisen.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 25, y: 15)
    }

    // MARK: – Planens fält
    private var fält: some View {
        Group {
            PlanField(titel: "Tidiga varningssignaler",
                      text: $store.plan.tidiga,
                      minHeight: minFältHöjd,
                      placeholder: "Tankar, känslor, beteenden …",
                      symbol: "waveform.path.ecg")

            PlanField(titel: "Vad jag kan göra själv",
                      text: $store.plan.göra,
                      minHeight: minFältHöjd,
                      placeholder: "Konkreta steg …",
                      symbol: "checkmark.circle")

            PlanField(titel: "Lugnande strategier",
                      text: $store.plan.strategier,
                      minHeight: minFältHöjd,
                      placeholder: "Musik, andning, mindfulness …",
                      symbol: "leaf")

            PlanField(titel: "Saker att undvika",
                      text: $store.plan.undvika,
                      minHeight: minFältHöjd,
                      placeholder: "Alkohol, konflikter …",
                      symbol: "nosign")

            PlanField(titel: "Trygg plats/miljö",
                      text: $store.plan.tryggPlats,
                      minHeight: minFältHöjd,
                      placeholder: "Soffan med filt …",
                      symbol: "house")

            PlanField(titel: "Kontaktpersoner (namn & tel.)",
                      text: $store.plan.kontakter,
                      minHeight: minFältHöjd,
                      placeholder: "Vänner, familj …",
                      symbol: "person.2")

            PlanField(titel: "Professionell hjälp",
                      text: $store.plan.proHjälp,
                      minHeight: minFältHöjd,
                      placeholder: "Akutpsykiatri, 1177 …",
                      symbol: "stethoscope")

            PlanField(titel: "Akutnummer",
                      text: $store.plan.akut,
                      minHeight: 64,
                      placeholder: "112",
                      symbol: "phone.fill")

            PlanField(titel: "Pepp till mig själv",
                      text: $store.plan.pepp,
                      minHeight: minFältHöjd,
                      placeholder: "”Jag klarar detta!”",
                      symbol: "sparkles")
        }
    }

    // MARK: – Nederpanelen (flyttad in i ScrollView-innehållet)
    private var nederPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                knapp(titel: "Spara i molnet", system: "icloud.and.arrow.up") {
                    Task {
                        do {
                            try store.sparaLokalt()
                            try await store.sparaTillFirebase()
                            alertText = "Krisplanen sparades lokalt och i Firebase."
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            alertText = "Kunde inte spara: \(error.localizedDescription)"
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                        visaAlert = true
                    }
                }
                knapp(titel: "Hem", system: "house.fill") {
                    visaHem = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            // Flytande glasbar med rundade hörn runtom
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.08)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 6)
                .background(
                    LinearGradient(colors: [.black.opacity(0.10), .black.opacity(0.30)],
                                   startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: – Knapp
    private func knapp(titel: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(titel, systemImage: system)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: knappHöjd)
                .background(
                    LinearGradient(colors: [.blue, .purple],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                        .opacity(0.95)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Förhandsvisning
#Preview {
    KrisplanView()
        .preferredColorScheme(.dark)
        .environment(\.locale, .init(identifier: "sv_SE"))
}

// MARK: – Modell
struct KrisplanEntry: Identifiable, Codable {
    let id: UUID
    var tidiga, göra, strategier, undvika, tryggPlats,
        kontakter, proHjälp, akut, pepp: String
    var updatedAt: Date

    init(
        id: UUID = .init(),
        tidiga: String = "",
        göra: String = "",
        strategier: String = "",
        undvika: String = "",
        tryggPlats: String = "",
        kontakter: String = "",
        proHjälp: String = "",
        akut: String = "112",
        pepp: String = "",
        updatedAt: Date = .now
    ) {
        self.id         = id
        self.tidiga     = tidiga
        self.göra       = göra
        self.strategier = strategier
        self.undvika    = undvika
        self.tryggPlats = tryggPlats
        self.kontakter  = kontakter
        self.proHjälp   = proHjälp
        self.akut       = akut
        self.pepp       = pepp
        self.updatedAt  = updatedAt
    }
}

// MARK: – Persistens + Firebase-synk
@MainActor
final class KrisplanStore: ObservableObject {
    @Published var plan: KrisplanEntry
    private let url: URL
    private let remote = KrisplanRemote()

    init() {
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Krisplan.json")

        if let data = try? Data(contentsOf: url),
           let sparad = try? JSONDecoder().decode(KrisplanEntry.self, from: data) {
            plan = sparad
        } else {
            plan = KrisplanEntry()
        }
    }

    func sparaLokalt() throws {
        var p = plan
        p.updatedAt = .now
        plan = p

        let data = try JSONEncoder().encode(plan)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func startMolnInit() {
        Task {
            // Hämta från Firebase om nyare än lokalt
            if let fjärr = try? await remote.hämta(),
               fjärr.updatedAt > plan.updatedAt {
                plan = fjärr
                try? sparaLokalt()
            }
        }
    }

    func sparaTillFirebase() async throws {
        try await remote.spara(plan: plan)
    }
}

// MARK: – Firebase-klient
actor KrisplanRemote {
    enum RemoteError: LocalizedError {
        case ejInloggad
        var errorDescription: String? { "Ingen användare inloggad." }
    }

    #if canImport(FirebaseCore)
    private func ensureFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    #endif

    func spara(plan: KrisplanEntry) async throws {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth) && canImport(FirebaseCore)
        ensureFirebase()
        guard let uid = Auth.auth().currentUser?.uid else { throw RemoteError.ejInloggad }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("krisplan").document("current")

        let data: [String: Any] = [
            "id": plan.id.uuidString,
            "tidiga": plan.tidiga,
            "göra": plan.göra,
            "strategier": plan.strategier,
            "undvika": plan.undvika,
            "tryggPlats": plan.tryggPlats,
            "kontakter": plan.kontakter,
            "proHjälp": plan.proHjälp,
            "akut": plan.akut,
            "pepp": plan.pepp,
            // dubbla tidsstämplar
            "updatedAtClient": plan.updatedAt.timeIntervalSince1970,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: true)
        #else
        // Firebase ej installerat – gör inget (bygget kompilerar ändå)
        #endif
    }

    func hämta() async throws -> KrisplanEntry? {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth) && canImport(FirebaseCore)
        ensureFirebase()
        guard let uid = Auth.auth().currentUser?.uid else { throw RemoteError.ejInloggad }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("krisplan").document("current")
        let snap = try await ref.getDocument()
        guard let d = snap.data() else { return nil }

        let updatedClient = (d["updatedAtClient"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .distantPast

        return KrisplanEntry(
            id: UUID(uuidString: (d["id"] as? String) ?? "") ?? UUID(),
            tidiga: d["tidiga"] as? String ?? "",
            göra: d["göra"] as? String ?? "",
            strategier: d["strategier"] as? String ?? "",
            undvika: d["undvika"] as? String ?? "",
            tryggPlats: d["tryggPlats"] as? String ?? "",
            kontakter: d["kontakter"] as? String ?? "",
            proHjälp: d["proHjälp"] as? String ?? "",
            akut: d["akut"] as? String ?? "112",
            pepp: d["pepp"] as? String ?? "",
            updatedAt: updatedClient
        )
        #else
        return nil
        #endif
    }
}

// MARK: – GPT-4o-mini
actor GPTAssistant {
    // Låt dina API-nycklar vara kvar här
    private let apiKey = "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"
    private let url    = URL(string: "https://api.openai.com/v1/chat/completions")!

    func förslag(från plan: KrisplanEntry) async throws -> String {
        let sammanfattning = """
        Tidiga varningssignaler: \(plan.tidiga)
        Vad jag kan göra: \(plan.göra)
        Lugnande strategier: \(plan.strategier)
        Saker att undvika: \(plan.undvika)
        Trygg plats: \(plan.tryggPlats)
        Kontaktpersoner: \(plan.kontakter)
        Professionell hjälp: \(plan.proHjälp)
        Akutnummer: \(plan.akut)
        Pepp: \(plan.pepp)
        """

        struct Req: Encodable {
            struct Msg: Encodable { let role, content: String }
            let model: String
            let messages: [Msg]
        }
        struct Res: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }

        let body = Req(model: "gpt-4o-mini",
                       messages: [.init(role: "user",
                                        content: "Du är psykolog. Ge max åtta konkreta förbättringsförslag, punktlista:\n\(sammanfattning)")])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let res = try JSONDecoder().decode(Res.self, from: data)
        return res.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: – Fält (glas + ikon)
private struct PlanField: View {
    let titel: LocalizedStringKey
    @Binding var text: String
    let minHeight: CGFloat
    let placeholder: String
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 22)
                }
                Text(titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .foregroundColor(.white)
                    .tint(.white)
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 10)

                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.top, 16)
                        .padding(.leading, 14)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.08)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
        }
    }
}

// MARK: – Animerad bakgrund
private struct AuroraBackground: View {
    @State private var move = false

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            let blurLarge = d * 0.28
            let blurMedium = d * 0.24
            let blurSmall = d * 0.26

            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.9)],
                               startPoint: .top, endPoint: .bottom)

                // Blob 1 – scales with screen
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.9), .blue.opacity(0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: d * 1.10, height: d * 1.10)
                    .blur(radius: blurLarge)
                    .offset(x: move ? -0.22 * d : 0.11 * d,
                            y: move ? -0.50 * d : -0.35 * d)
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: move)

                // Blob 2 – scales with screen
                Circle()
                    .fill(LinearGradient(colors: [.indigo.opacity(0.8), .cyan.opacity(0.7)],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
                    .frame(width: d * 0.95, height: d * 0.95)
                    .blur(radius: blurMedium)
                    .offset(x: move ? 0.30 * d : -0.16 * d,
                            y: move ? 0.36 * d : 0.47 * d)
                    .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: move)

                // Blob 3 – scales with screen
                Circle()
                    .fill(LinearGradient(colors: [.pink.opacity(0.7), .purple.opacity(0.5)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: d * 0.85, height: d * 0.85)
                    .blur(radius: blurSmall)
                    .offset(x: move ? 0.09 * d : -0.28 * d,
                            y: move ? 0.14 * d : -0.10 * d)
                    .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: move)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .drawingGroup()
        }
        .onAppear { move = true }
    }
}
