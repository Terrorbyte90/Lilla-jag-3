//
//  UkraineView.swift
//  Lilla jag 3
//
//  Created by Ted Svärd on 2025-07-29.
//  Updated 2026-02-20 – Fullständig vy för stöd till Ukraina
//

import SwiftUI

struct UkraineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var animate = false
    
    private let organizations: [SupportOrg] = [
        .init(name: "Blågula Bilen", description: "Levererar fordon och förnödenheter direkt till frontlinjen.", url: "https://www.blagulabilen.se", swish: "123 123 1234"),
        .init(name: "UNICEF", description: "Hjälper barn och familjer på flykt med rent vatten, mat och skydd.", url: "https://www.unicef.se/ukraina", swish: "902 00 17"),
        .init(name: "Röda Korset", description: "Ger akut nödhjälp, mediciner och psykosocialt stöd på plats.", url: "https://www.rodakorset.se/ukraina", swish: "900 80 04"),
        .init(name: "Läkare Utan Gränser", description: "Medicinsk hjälp till skadade och sjuka i krigsdrabbade områden.", url: "https://www.lakareutangranser.se", swish: "900 60 32")
    ]
    
    var body: some View {
        ZStack {
            // Ukrainas flagga som bakgrundsgradient
            LinearGradient(colors: [Color(hex: 0x0057B7), Color(hex: 0xFFD700)], 
                           startPoint: .top, endPoint: .bottom)
                .opacity(0.15)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .blur(radius: 10)
                            
                            Image(systemName: "heart.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .yellow], startPoint: .top, endPoint: .bottom)
                                )
                                .scaleEffect(animate ? 1.1 : 0.9)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
                        }
                        .onAppear { animate = true }
                        
                        Text("Stöd Ukraina")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Tillsammans gör vi skillnad för de som drabbats av kriget.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // Organisationslista
                    VStack(spacing: 16) {
                        ForEach(organizations) { org in
                            SupportOrgCard(org: org)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Info-ruta
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Varför detta?")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Lilla Jag står för medmänsklighet och trygghet. Kriget i Ukraina påverkar oss alla, och genom att bidra till etablerade organisationer kan vi hjälpa till att lindra lidandet.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding()
        }
    }
}

struct SupportOrg: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let url: String
    let swish: String
}

struct SupportOrgCard: View {
    let org: SupportOrg
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(org.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right.circle")
                    .foregroundStyle(.blue)
            }
            
            Text(org.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            HStack {
                if !org.swish.isEmpty {
                    Label(org.swish, systemImage: "iphone.radiowaves.left.and.right")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1), in: Capsule())
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button("Besök hemsida") {
                    if let url = URL(string: org.url) {
                        openURL(url)
                    }
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    UkraineView()
}
