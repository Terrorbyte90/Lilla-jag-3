//
//  Inlogg.swift
//  LillaJag
//
//  Skapad 13 aug 2025 av ChatGPT (GPT-5 Thinking)
//  Inloggning med Firebase (E-post + Apple), separata sidor för ”Glömt lösenord” & ”Skapa konto”.
//  Navigerar till ContentView som fullskärm (utan back-knapp) efter lyckad inloggning.
//

import SwiftUI
import AVFoundation
import AVKit
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth

// MARK: - Inlogg (huvudvy)
public struct Inlogg: View {
    @AppStorage("auth_isLoggedIn") private var savedLoggedIn: Bool = false
    
    // UI-tillstånd
    @State private var authState: AuthState = .checking
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isLoadingPrimary: Bool = false
    @State private var showMain: Bool = false
    @State private var showForgotSheet: Bool = false
    @State private var showCreateSheet: Bool = false
    @FocusState private var focusedField: Field?
    
    // Apple Sign In nonce
    @State private var appleSignInNonce: String = ""
    
    // Valfri callback
    public var onContinue: (() -> Void)? = nil
    
    public init(onContinue: (() -> Void)? = nil) {
        self.onContinue = onContinue
    }
    
    public var body: some View {
        ZStack {
            BackgroundGradient().ignoresSafeArea()
            FloatingOrbs().allowsHitTesting(false)
            
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
        }
        .task {
            ensureFirebaseConfigured()
            await checkAuth()
        }
        .onTapGesture { endEditing() }
        
        // Navigera till ContentView utan back-knapp
        .fullScreenCover(isPresented: $showMain) {
            ContentView()
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
                .interactiveDismissDisabled(true)
        }
        
        // Öppna glömt-lösenord
        .sheet(isPresented: $showForgotSheet) {
            ForgotPasswordSheet(initialEmail: email) {
                Toast.show("Återställningsmail skickat om adressen finns.")
            }
        }
        
        // Öppna skapa konto
        .sheet(isPresented: $showCreateSheet) {
            CreateAccountSheet(initialEmail: email) {
                // Lyckad kontoskapning -> inloggad -> gå vidare
                self.authState = .authenticated
            }
        }
        
        // När auth lyckas, visa ContentView
        .onChange(of: authState) {
            if case .authenticated = authState {
                savedLoggedIn = true
                showMain = true
                onContinue?()
            }
        }
    }
}

// MARK: - UI-byggstenar
private extension Inlogg {
    enum AuthState { case checking, loggedOut, authenticated }
    enum Field { case email, password }
    
    var content: some View {
        Group {
            switch authState {
            case .checking:
                CheckingView()
            case .authenticated:
                AlreadyLoggedInView(onContinue: { showMain = true })
            case .loggedOut:
                LoginCard(
                    email: $email,
                    password: $password,
                    showPassword: $showPassword,
                    isLoadingPrimary: $isLoadingPrimary,
                    onPrimaryTap: primaryButtonTapped,
                    onAppleRequest: appleButtonRequest,
                    onAppleCompletion: appleButtonCompletion,
                    onForgotTap: { showForgotSheet = true },
                    onCreateTap: { showCreateSheet = true }
                )
                .focused($focusedField, equals: .email)
                .onAppear { focusedField = .email }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: authState)
    }
    
    // MARK: - Åtgärder
    func primaryButtonTapped() {
        guard !isLoadingPrimary else { return }
        Haptics.tap()
        loginWithEmail()
    }
    
    func endEditing() {
        UIApplication.shared.endEditing()
    }
    
    func checkAuth() async {
        try? await Task.sleep(nanoseconds: 250_000_000)
        if let user = Auth.auth().currentUser, !user.uid.isEmpty {
            await MainActor.run { self.authState = .authenticated }
        } else {
            await MainActor.run { self.authState = savedLoggedIn ? .authenticated : .loggedOut }
        }
    }
}

// MARK: - Firebase init
private extension Inlogg {
    func ensureFirebaseConfigured() {
        if FirebaseApp.app() == nil {
            if let options = FirebaseOptions.defaultOptions() {
                FirebaseApp.configure(options: options)
            } else {
                // Saknar GoogleService-Info.plist – krascha inte
                print("[Firebase] GoogleService-Info.plist saknas. Konfiguration hoppad över.")
            }
        }
    }
}

// MARK: - E-post & lösenord
private extension Inlogg {
    func loginWithEmail() {
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mail.isEmpty, !password.isEmpty else {
            Toast.show("Fyll i e-post och lösenord.")
            return
        }
        isLoadingPrimary = true
        ensureFirebaseConfigured()
        
        Auth.auth().signIn(withEmail: mail, password: password) { _, error in
            if let error = error as NSError? {
                isLoadingPrimary = false
                Haptics.tap()
                switch error.code {
                case AuthErrorCode.userNotFound.rawValue:
                    Toast.show("Ingen användare hittades. Skapa ett konto.")
                case AuthErrorCode.wrongPassword.rawValue:
                    Toast.show("Fel lösenord. Försök igen eller återställ.")
                case AuthErrorCode.invalidEmail.rawValue:
                    Toast.show("Ogiltig e-postadress.")
                default:
                    Toast.show(error.localizedDescription)
                }
            } else {
                Haptics.tap()
                isLoadingPrimary = false
                authState = .authenticated
            }
        }
    }
}

// MARK: - Apple Sign In -> Firebase
private extension Inlogg {
    func appleButtonRequest(_ request: ASAuthorizationAppleIDRequest) {
        ensureFirebaseConfigured()
        let nonce = randomNonceString()
        appleSignInNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func appleButtonCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            Haptics.tap()
            Toast.show(error.localizedDescription)
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                Toast.show("Kunde inte läsa Apple-token.")
                return
            }
            // Rätt api i nya FirebaseAuth
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: appleSignInNonce,
                fullName: appleIDCredential.fullName
            )
            ensureFirebaseConfigured()
            Auth.auth().signIn(with: credential) { _, error in
                if let error = error {
                    Haptics.tap()
                    Toast.show(error.localizedDescription)
                } else {
                    Haptics.tap()
                    authState = .authenticated
                }
            }
        }
    }
    
    // Slumpad nonce
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess { fatalError("Kan inte generera slumpdata: \(errorCode)") }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count { result.append(charset[Int(random)]) ; remaining -= 1 }
            }
        }
        return result
    }
    
    // SHA256 för Apple-nonce
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Delvy: Bakgrund
private struct BackgroundGradient: View {
    // Använder RGB för att undvika krock med din egen init(hex:alpha:), men behåller identiska färger.
    private var gradientColors: [Color] {
        [
            Color(red: 7/255,  green: 11/255, blue: 22/255),  // 0x070B16
            Color(red: 13/255, green: 27/255, blue: 42/255),  // 0x0D1B2A
            Color(red: 19/255, green: 42/255, blue: 74/255),  // 0x132A4A
            Color(red: 10/255, green: 18/255, blue: 36/255)   // 0x0A1224
        ]
    }
    var body: some View {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// Hjälpvy för att minska typ-checking-komplexitet
private struct StrokeOverlay: View {
    let cornerRadius: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Delvy: Orbs
private struct FloatingOrbs: View {
    @State private var move: Bool = false
    var body: some View {
        ZStack {
            orb(color: Color.purple.opacity(0.35), size: 280)
                .offset(x: move ? -160 : 40, y: move ? -220 : -120)
            orb(color: Color.blue.opacity(0.28), size: 220)
                .offset(x: move ? 150 : -60, y: move ? 180 : 120)
            orb(color: Color.cyan.opacity(0.22), size: 320)
                .offset(x: move ? -40 : 120, y: move ? 220 : -80)
        }
        .blur(radius: 60)
        .task {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                move.toggle()
            }
        }
    }
    
    func orb(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blendMode(.screen)
    }
}

// MARK: - Delvy: Kontrollvy när vi kollar auth
private struct CheckingView: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .tint(.white.opacity(0.9))
            Text("Kontrollerar inloggning…")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(StrokeOverlay(cornerRadius: 20))
    }
}

// MARK: - Delvy: Redan inloggad
private struct AlreadyLoggedInView: View {
    var onContinue: () -> Void
    @State private var appear: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(appear ? 1.0 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appear)
            
            Text("Välkommen tillbaka")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("Du är redan inloggad på den här enheten.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
            
            Button(action: onContinue) {
                Text("Gå vidare")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 18, y: 8)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(StrokeOverlay(cornerRadius: 24))
        .onAppear { appear = true }
    }
}

// MARK: - Delvy: Login-kortet (Frontend + kopplingar)
private struct LoginCard: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var showPassword: Bool
    @Binding var isLoadingPrimary: Bool
    
    var onPrimaryTap: () -> Void
    var onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onAppleCompletion: (Result<ASAuthorization, Error>) -> Void
    var onForgotTap: () -> Void
    var onCreateTap: () -> Void
    
    // Lokal video: lägg en fil "login_bg.mp4" i projektet (valfritt).
    private var bundledVideoURL: URL? { Bundle.main.url(forResource: "login_bg", withExtension: "mp4") }
    
    var body: some View {
        VStack(spacing: 18) {
            // Branding + videobanner
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 42, height: 42)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.25)))
                        Image(systemName: "sparkles").foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lilla Jag").font(.title3.weight(.semibold)).foregroundStyle(.white)
                        Text("Din lugna plats på nätet").font(.footnote).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                }
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 180)
                    .overlay(LoopingPlayerView(url: bundledVideoURL).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)))
                    .overlay(StrokeOverlay(cornerRadius: 18))
            }
            .padding(.bottom, 2)
            
            // Textfält
            VStack(spacing: 12) {
                FancyField(icon: "envelope.open.fill", placeholder: "E-post", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                
                FancySecureField(icon: "lock.fill", placeholder: "Lösenord", text: $password, showPassword: $showPassword)
                    .textContentType(.password)
            }
            .padding(.top, 4)
            
            // Primärknapp (e-post)
            Button(action: onPrimaryTap) {
                HStack(spacing: 10) {
                    if isLoadingPrimary { ProgressView().tint(.white) } else { Image(systemName: "arrow.right.circle.fill").imageScale(.large) }
                    Text("Logga in").font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .purple.opacity(0.4), radius: 18, y: 8)
            }
            .disabled(isLoadingPrimary)
            .opacity(isLoadingPrimary ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.2), value: isLoadingPrimary)
            .padding(.top, 2)
            
            // Divider ”eller”
            HStack {
                Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                Text("eller").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
            }
            .padding(.vertical, 4)
            
            // Apple-knapp
            SignInWithAppleButton(.signIn, onRequest: onAppleRequest, onCompletion: onAppleCompletion)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.1)))
                .signInWithAppleButtonStyle(.whiteOutline)
            
            // Hjälplänkar
            HStack {
                Button(role: .none, action: onForgotTap) {
                    Text("Glömt lösenord?")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .underline()
                }
                Spacer()
                Button(role: .none, action: onCreateTap) {
                    Text("Skapa konto")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .underline()
                }
            }
            .padding(.top, 2)
            
            Text("Genom att fortsätta godkänner du våra användarvillkor och integritetspolicy.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(StrokeOverlay(cornerRadius: 28))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .overlay(TopGlow(), alignment: .top)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Fancy fält
private struct FancyField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    init(icon: String, placeholder: String, text: Binding<String>) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 22)
            
            TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.5)))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.18)))
    }
}

private struct FancySecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 22)

            if showPassword {
                TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.5)))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.5)))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showPassword.toggle() }
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityLabel(showPassword ? "Dölj lösenord" : "Visa lösenord")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.18)))
    }
}

// MARK: - TopGlow
private struct TopGlow: View {
    var body: some View {
        LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: 2)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(.horizontal, 24)
            .padding(.top, 2)
    }
}

// MARK: - Video (loop, tyst, inga kontroller). Svart fallback om URL saknas.
private struct LoopingPlayerView: View {
    let url: URL?
    @State private var player: AVQueuePlayer? = nil
    @State private var looper: AVPlayerLooper? = nil
    
    var body: some View {
        ZStack {
            if let url {
                VideoPlayerContainer(player: makePlayer(for: url))
                    .onDisappear { player?.pause() }
            } else {
                Color.black
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { player?.play() }
    }
    
    private func makePlayer(for url: URL) -> AVQueuePlayer {
        if let existing = player { return existing }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let qPlayer = AVQueuePlayer()
        qPlayer.isMuted = true
        qPlayer.actionAtItemEnd = .advance
        let looper = AVPlayerLooper(player: qPlayer, templateItem: item)
        qPlayer.play()
        self.player = qPlayer
        self.looper = looper
        return qPlayer
    }
}

private struct VideoPlayerContainer: UIViewRepresentable {
    let player: AVQueuePlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.player = player
        return v
    }
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
    }
    
    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var player: AVPlayer? {
            get { playerLayer.player }
            set {
                playerLayer.player = newValue
                playerLayer.videoGravity = .resizeAspectFill
            }
        }
    }
}

// MARK: - Hjälp: Haptik, Toast, färger, app-helpers
private enum Haptics { static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }

private struct Toast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    
    static func show(_ message: String) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        
        let hosting = UIHostingController(rootView: ToastView(message: message))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            hosting.view.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 24),
            hosting.view.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -24)
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            hosting.view.removeFromSuperview()
        }
    }
}

private struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25)))
            .shadow(radius: 8, y: 4)
    }
}

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Glömt lösenord (sheet)
private struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var isSending: Bool = false
    let onSent: () -> Void
    
    init(initialEmail: String, onSent: @escaping () -> Void) {
        _email = State(initialValue: initialEmail)
        self.onSent = onSent
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Vi skickar en länk för att återställa ditt lösenord.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.primary.opacity(0.8))
                    TextField("E-post", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                
                Button {
                    sendReset()
                } label: {
                    if isSending {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Skicka återställningsmail")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isSending || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Glömt lösenord")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stäng") { dismiss() }
                }
            }
        }
    }
    
    private func sendReset() {
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mail.isEmpty else { return }
        isSending = true
        if FirebaseApp.app() == nil, let options = FirebaseOptions.defaultOptions() { FirebaseApp.configure(options: options) }
        Auth.auth().sendPasswordReset(withEmail: mail) { error in
            isSending = false
            if let error = error {
                Toast.show(error.localizedDescription)
            } else {
                Haptics.tap()
                onSent()
                dismiss()
            }
        }
    }
}

// MARK: - Skapa konto (sheet)
private struct CreateAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var password: String = ""
    @State private var confirm: String = ""
    @State private var isCreating: Bool = false
    @FocusState private var focused: Field?
    let onCreated: () -> Void
    
    enum Field { case mail, pass, confirm }
    
    init(initialEmail: String, onCreated: @escaping () -> Void) {
        _email = State(initialValue: initialEmail)
        self.onCreated = onCreated
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Skapa ett nytt konto med e-post och lösenord.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Group {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill").foregroundStyle(.primary.opacity(0.8))
                        TextField("E-post", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($focused, equals: .mail)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                    
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundStyle(.primary.opacity(0.8))
                        SecureField("Lösenord (minst 6 tecken)", text: $password)
                            .textContentType(.newPassword)
                            .focused($focused, equals: .pass)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                    
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill").foregroundStyle(.primary.opacity(0.8))
                        SecureField("Bekräfta lösenord", text: $confirm)
                            .textContentType(.newPassword)
                            .focused($focused, equals: .confirm)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                }
                
                Button {
                    createAccount()
                } label: {
                    if isCreating {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Skapa konto")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isCreating || !canSubmit)
                .padding(.top, 6)
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Skapa konto")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stäng") { dismiss() }
                }
            }
            .onAppear { focused = .mail }
        }
    }
    
    private var canSubmit: Bool {
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !mail.isEmpty && password.count >= 6 && password == confirm
    }
    
    private func createAccount() {
        guard canSubmit else { return }
        isCreating = true
        if FirebaseApp.app() == nil, let options = FirebaseOptions.defaultOptions() { FirebaseApp.configure(options: options) }
        Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) { _, error in
            isCreating = false
            if let error = error {
                Toast.show(error.localizedDescription)
            } else {
                Haptics.tap()
                onCreated()
                dismiss()
            }
        }
    }
}

// MARK: - Förhandsvisningar
#Preview("Inloggad (auto)") {
    UserDefaults.standard.set(true, forKey: "auth_isLoggedIn")
    return Inlogg()
        .preferredColorScheme(.dark)
}

#Preview("Utloggad") {
    UserDefaults.standard.set(false, forKey: "auth_isLoggedIn")
    return Inlogg()
        .preferredColorScheme(.dark)
        .previewDevice("iPhone 15 Pro")
}
