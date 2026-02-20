//
//  DonationView.swift
//  Lilla Jag 3
//

import SwiftUI

struct DonationView: View {
    @Environment(\.openURL) private var openURL
    @State private var amountText: String = ""
    @State private var showHome: Bool = false
    @State private var pulse: Bool = false
    @State private var ripple: Bool = false

    private let swishNumber = "1236077887"

    var body: some View {
        ZStack {
            BackgroundCanvas()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {

                    // Kort med hjärta + text
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 20)

                        VStack(spacing: 16) {
                            // Hjärt-ikon – glow + puls + ring-ripple
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.pink.opacity(0.55), .purple.opacity(0.45)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 108, height: 108)
                                    .blur(radius: 14)
                                    .opacity(0.9)

                                Circle()
                                    .stroke(.pink.opacity(0.35), lineWidth: 3)
                                    .frame(width: 110, height: 110)
                                    .scaleEffect(ripple ? 1.35 : 0.9)
                                    .opacity(ripple ? 0.0 : 1.0)
                                    .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: ripple)

                                Image(systemName: "heart.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 68, height: 68)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .pink)
                                    .scaleEffect(pulse ? 1.06 : 0.94)
                                    .shadow(color: .pink.opacity(0.5), radius: 18, x: 0, y: 8)
                                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                            }
                            .padding(.top, 20)
                            .onAppear { pulse = true; ripple = true }

                            Text("Tack för att du använder Lilla Jag")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.95))

                            Text("""
Jag har byggt appen under mer än ett år – mycket tid, innehåll och egna kostnader. Det kostar också löpande att hålla alla funktioner igång. \nOm du vill och kan så hjälper en donation mig att fortsätta utveckla och drifta appen. 

Tipsa gärna dina vänner om appen och dela gärna på sociala medier. 

Varma hälsningar
Ted Svärd – Utvecklare
""")
                                // Samma fontfamilj (rounded) som "Stöd via Swish"
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 18)
                        }
                        .padding(.horizontal, 14)
                    }
                    .padding(.horizontal, 22)

                    // Swish-sektion
                    VStack(spacing: 12) {
                        Text("Stöd via Swish")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))

                        HStack(spacing: 10) {
                            Label("Swish-nummer", systemImage: "creditcard.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.75))

                            Text(swishNumber)
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(.white.opacity(0.08))
                                )
                                .overlay(
                                    Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
                                )
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 16)

                    // Belopp + snabbval
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Välj belopp (SEK)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 10) {
                            TextField("Belopp", text: $amountText)
                                .keyboardType(.decimalPad)
                                .textContentType(.oneTimeCode)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(.white.opacity(0.18), lineWidth: 1)
                                )
                                .foregroundColor(.white)

                            ForEach([50, 100, 200, 300], id: \.self) { v in
                                Button("\(v) kr") { amountText = "\(v)" }
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(.white.opacity(0.08)))
                                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 22)

                    // Swisha-knapp
                    Button(action: sendSwish) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text(swishButtonTitle)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                        .overlay(
                            Capsule().stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .blue.opacity(0.35), radius: 18, x: 0, y: 10)
                    }
                    .padding(.horizontal, 22)
                    .disabled(!isValidAmount)
                    .opacity(isValidAmount ? 1 : 0.55)

                    Spacer(minLength: 0)
                }
                .padding(.top, 90)
                .padding(.bottom, 42) // luft så att allt inte åker för långt ner + plats för Hem-knappen
            }
        }
        // Flytande rund Hem-knapp utan back-knapp
        .safeAreaInset(edge: .bottom) {
            Button {
                showHome = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "house.fill")
                    Text("Hem").fontWeight(.semibold)
                }
                .font(.title3)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
                .foregroundColor(.white)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 30)
            .background(Color.black.opacity(0.001))
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showHome) {
            ContentView()
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: – Hjälpvy: Bakgrund
private struct BackgroundCanvas: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.14),
                    Color(red: 0.09, green: 0.11, blue: 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            AngularGradient(
                colors: [.purple.opacity(0.12), .blue.opacity(0.12), .clear, .purple.opacity(0.12)],
                center: .center
            )
            .blur(radius: 80)
            .ignoresSafeArea()
        }
    }
}

// MARK: – Logik
private extension DonationView {
    var isValidAmount: Bool {
        guard let a = amountDouble else { return false }
        return a > 0
    }

    var swishButtonTitle: String {
        if let a = amountDouble {
            let intPart = Int(a.rounded())
            return "Swisha \(intPart) kr"
        } else {
            return "Swisha en slant"
        }
    }

    var amountDouble: Double? {
        let sanitized = amountText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(sanitized)
    }

    func sendSwish() {
        guard let amount = amountDouble, amount > 0 else { return }
        let formatted = String(format: "%.2f", amount)
        let urlString = "swish://paymentrequest?payee=\(swishNumber)&amount=\(formatted)&message=Donation"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}

// MARK: – Preview
struct DonationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DonationView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("DonationView")
    }
}
