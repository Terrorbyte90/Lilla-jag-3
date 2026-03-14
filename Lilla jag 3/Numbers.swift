// Numbers.swift
// Lilla Jag – Krisnummer

import SwiftUI

struct CrisisContact: Identifiable {
    let id = UUID()
    let name: String
    let number: String
    let description: String
    let availability: String
    let icon: String
    let color: Color
    let urgent: Bool
}

private let contacts: [CrisisContact] = [
    CrisisContact(name: "Självmordslinjen", number: "90101", description: "Stödsamtal om suicidtankar och livskris. Kostnadsfritt, anonymt.", availability: "Dygnet runt", icon: "cross.fill", color: Color(hex: 0xFF5B5B), urgent: true),
    CrisisContact(name: "Mind Självmordslinjen", number: "90101", description: "Chatt och samtal. Du kan vara anonym.", availability: "Dygnet runt", icon: "bubble.left.fill", color: Color(hex: 0xFF5B5B), urgent: true),
    CrisisContact(name: "SOS Alarm", number: "112", description: "Akut livsfara – ring 112.", availability: "Dygnet runt", icon: "phone.fill", color: Color(hex: 0xFF3B30), urgent: true),
    CrisisContact(name: "Bris", number: "116 111", description: "För barn och unga upp till 18 år.", availability: "Varierar", icon: "person.fill", color: Color.warmLavender, urgent: false),
    CrisisContact(name: "Äldrelinjen", number: "020-22 60 60", description: "För äldre som är ensamma eller behöver stöd.", availability: "Vardagar", icon: "heart.fill", color: Color.warmSage, urgent: false),
    CrisisContact(name: "1177 Sjukvårdsrådgivning", number: "1177", description: "Råd om psykisk och fysisk hälsa.", availability: "Dygnet runt", icon: "stethoscope", color: Color(hex: 0x6ECFF6), urgent: false),
    CrisisContact(name: "Polisen icke-akut", number: "114 14", description: "Vid behov av polisassistans utan akut fara.", availability: "Dygnet runt", icon: "shield.fill", color: Color.warmGold, urgent: false)
]

struct NumbersView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        urgentBanner

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Krisnummer")
                                .font(.system(.title2, design: .rounded, weight: .black))
                                .foregroundStyle(.white)
                            Text("Du är inte ensam. Ring – det är gratis och anonymt.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                        ForEach(contacts) { contact in
                            ContactCard(contact: contact)
                        }

                        VStack(spacing: 8) {
                            Text("Om du är i omedelbar fara för ditt liv – ring 112.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var urgentBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: 0xFF5B5B))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Akut hjälp")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("Ring 90101 eller 112 om du har suicidtankar")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Link(destination: URL(string: "tel:90101")!) {
                Text("Ring nu")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0xFF5B5B), in: Capsule())
            }
        }
        .padding(14)
        .background(Color(hex: 0xFF5B5B).opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xFF5B5B).opacity(0.3), lineWidth: 1))
    }
}

struct ContactCard: View {
    let contact: CrisisContact

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(contact.color.opacity(0.2)).frame(width: 48, height: 48)
                Image(systemName: contact.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(contact.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(contact.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label(contact.availability, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            Link(destination: URL(string: "tel:\(contact.number.replacingOccurrences(of: " ", with: ""))")!) {
                VStack(spacing: 2) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 14))
                    Text(contact.number)
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(contact.color.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(contact.color.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(12)
        .background(contact.urgent ? Color(hex: 0xFF5B5B).opacity(0.08) : Color.white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(contact.urgent ? Color(hex: 0xFF5B5B).opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    NumbersView()
}
