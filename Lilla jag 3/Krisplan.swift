// Krisplan.swift
// Lilla Jag – Personlig Krisplan

import SwiftUI

// MARK: - Data model

struct KrisplanData: Codable {
    var warningSigns: String = ""
    var copingStrategies: [String] = ["", "", ""]
    var supportContacts: [SupportContact] = []
    var safeEnvironments: String = ""
    var professionalContact: String = ""
    var emergencyNote: String = ""

    struct SupportContact: Codable, Identifiable {
        var id = UUID()
        var name: String = ""
        var phone: String = ""
        var relation: String = ""
    }
}

@MainActor
final class KrisplanStore: ObservableObject {
    static let shared = KrisplanStore()
    @Published var plan = KrisplanData()

    private let url: URL

    init() {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = doc.appendingPathComponent("krisplan.json")
        load()
        if plan.warningSigns.isEmpty { loadExample() }
    }

    func save() {
        try? JSONEncoder().encode(plan).write(to: url)
    }

    private func load() {
        guard let d = try? Data(contentsOf: url),
              let p = try? JSONDecoder().decode(KrisplanData.self, from: d) else { return }
        plan = p
    }

    private func loadExample() {
        plan.warningSigns = "Jag sover sämre, drar mig undan socialt och har ökad negativ tankeström."
        plan.copingStrategies = [
            "Gå ut och promenera i 15 minuter",
            "Ring en vän eller familjemedlem",
            "Kör 4-7-8 andningsövningen i appen"
        ]
        plan.safeEnvironments = "Hemma, i naturen, hos mamma."
        plan.professionalContact = "1177 eller min BUP-kontakt"
    }
}

// MARK: - KrisplanView

struct KrisplanView: View {
    @StateObject private var store = KrisplanStore.shared
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        // Akutknapp
                        emergencySection

                        krisSection(icon: "eye.fill", color: Color.warmGold, title: "Mina varningssignaler",
                                    text: store.plan.warningSigns,
                                    placeholder: "Hur märker du att du mår sämre?") { newText in
                            store.plan.warningSigns = newText
                        }

                        copingSection

                        contactsSection

                        krisSection(icon: "house.fill", color: Color.warmSage, title: "Trygga platser",
                                    text: store.plan.safeEnvironments,
                                    placeholder: "Var mår du bra?") { newText in
                            store.plan.safeEnvironments = newText
                        }

                        krisSection(icon: "stethoscope", color: Color(hex: 0x6ECFF6), title: "Professionell kontakt",
                                    text: store.plan.professionalContact,
                                    placeholder: "Ex: min terapeut, 1177, psykiatrin") { newText in
                            store.plan.professionalContact = newText
                        }

                        // Mind info
                        mindInfo
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Min krisplan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Spara" : "Redigera") {
                        if isEditing { store.save() }
                        isEditing.toggle()
                    }
                    .foregroundStyle(isEditing ? Color.warmGold : .white.opacity(0.7))
                    .fontWeight(isEditing ? .bold : .regular)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var emergencySection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(hex: 0xFF5B5B))
                Text("Om det är akut")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                if let url90101 = URL(string: "tel:90101") {
                    Link(destination: url90101) {
                        Label("90101", systemImage: "phone.fill")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: 0xFF5B5B), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let url112 = URL(string: "tel:112") {
                    Link(destination: url112) {
                        Label("112", systemImage: "phone.fill")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: 0xFF3B30), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: 0xFF5B5B).opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xFF5B5B).opacity(0.25), lineWidth: 1))
    }

    private var copingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.heart.fill").foregroundStyle(Color.warmLavender)
                Text("Mina copingstrategier")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }

            ForEach(Array(store.plan.copingStrategies.enumerated()), id: \.offset) { index, strategy in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.warmLavender)
                        .frame(width: 20, height: 20)
                        .background(Color.warmLavender.opacity(0.2), in: Circle())

                    if isEditing {
                        TextField("Strategi \(index + 1)", text: Binding(
                            get: { store.plan.copingStrategies[index] },
                            set: { store.plan.copingStrategies[index] = $0 }
                        ))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text(strategy.isEmpty ? "Lägg till strategi..." : strategy)
                            .font(.subheadline)
                            .foregroundStyle(strategy.isEmpty ? .white.opacity(0.3) : .white)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warmLavender.opacity(0.2), lineWidth: 1))
    }

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill").foregroundStyle(Color.warmRose)
                Text("Kontaktpersoner")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if isEditing {
                    Button {
                        store.plan.supportContacts.append(KrisplanData.SupportContact())
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.warmRose)
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.plan.supportContacts.isEmpty {
                Text(isEditing ? "Tryck + för att lägga till kontakter" : "Inga kontakter sparade")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            ForEach($store.plan.supportContacts) { $contact in
                if isEditing {
                    VStack(spacing: 6) {
                        TextField("Namn", text: $contact.name)
                            .foregroundStyle(.white).padding(8)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        HStack(spacing: 6) {
                            TextField("Telefon", text: $contact.phone)
                                .foregroundStyle(.white).padding(8)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            TextField("Relation", text: $contact.relation)
                                .foregroundStyle(.white).padding(8)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(contact.relation).font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        if !contact.phone.isEmpty,
                           let telURL = URL(string: "tel:\(contact.phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                            Link(destination: telURL) {
                                Label(contact.phone, systemImage: "phone.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.warmRose)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warmRose.opacity(0.2), lineWidth: 1))
    }

    private func krisSection(icon: String, color: Color, title: String, text: String, placeholder: String, onUpdate: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }

            if isEditing {
                TextEditor(text: Binding(get: { text }, set: onUpdate))
                    .frame(minHeight: 70)
                    .padding(8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .font(.subheadline)
                    .foregroundStyle(text.isEmpty ? .white.opacity(0.3) : .white)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private var mindInfo: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.circle.fill")
                .font(.title)
                .foregroundStyle(Color.warmLavender)
            Text("Mind – Självmordslinjen")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Ring 90101 eller chatta på mind.se.\nKostnadsfritt och anonymt, dygnet runt.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.warmLavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    KrisplanView()
}
