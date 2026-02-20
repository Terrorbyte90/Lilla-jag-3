//
//  FText.swift
//  Lilla jag 3
//
//  Skapad av Ted Svärd 2025-08-13
//

import SwiftUI
import FirebaseCore

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

final class FTextViewModel: ObservableObject {
    @Published var input: String = "Hej från Lilla Jag 3 👋"
    @Published var fetched: String = ""
    @Published var status: String = "• redo"

    // Säkerställ Firebase + anonym inloggning (request.auth != null)
    private func ensureSignedIn(_ completion: @escaping (Bool) -> Void) {
        guard FirebaseApp.app() != nil else {
            status = "⚠️ Firebase ej initierat (kör appen på enhet/simulator, inte bara Preview)"
            completion(false)
            return
        }
        #if canImport(FirebaseAuth)
        if Auth.auth().currentUser != nil {
            completion(true); return
        }
        status = "• loggar in anonymt…"
        Auth.auth().signInAnonymously { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.status = "✗ anonym inloggning misslyckades: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                self?.status = "✓ inloggad anonymt"
                completion(true)
            }
        }
        #else
        status = "⚠️ Lägg till FirebaseAuth i SPM (FirebaseAuth) eller öppna regler för dev"
        completion(false)
        #endif
    }

    func writeAndRead() {
        ensureSignedIn { [weak self] ok in
            guard let self = self, ok else { return }

            #if canImport(FirebaseFirestore)
            self.status = "• skriver till Firestore…"
            let db = Firestore.firestore()
            let doc = db.collection("ftext").document("preview")
            let data: [String: Any] = [
                "message": self.input,
                "timestamp": FieldValue.serverTimestamp()
            ]
            doc.setData(data, merge: true) { [weak self] err in
                DispatchQueue.main.async {
                    if let err = err {
                        self?.status = "✗ Firestore skrivfel: \(err.localizedDescription)"
                        return
                    }
                    self?.status = "✓ sparat – läser från Firestore…"
                    doc.getDocument { snap, err in
                        DispatchQueue.main.async {
                            if let err = err {
                                self?.status = "✗ Firestore läsfel: \(err.localizedDescription)"
                                return
                            }
                            let msg = snap?.get("message") as? String ?? "(tomt)"
                            self?.fetched = msg
                            self?.status = "✓ klart (Firestore)"
                        }
                    }
                }
            }

            #elseif canImport(FirebaseDatabase)
            self.status = "• skriver till Realtime DB…"
            let ref = Database.database().reference().child("ftext/preview")
            let data: [String: Any] = [
                "message": self.input,
                "timestamp": ServerValue.timestamp()
            ]
            ref.updateChildValues(data) { [weak self] err, _ in
                DispatchQueue.main.async {
                    if let err = err {
                        self?.status = "✗ RTDB skrivfel: \(err.localizedDescription)"
                        return
                    }
                    self?.status = "✓ sparat – läser från Realtime DB…"
                    ref.child("message").observeSingleEvent(of: .value) { snap in
                        DispatchQueue.main.async {
                            let msg = snap.value as? String ?? "(tomt)"
                            self?.fetched = msg
                            self?.status = "✓ klart (Realtime DB)"
                        }
                    }
                }
            }

            #else
            self.status = "⚠️ Lägg till FirebaseFirestore eller FirebaseDatabase via SPM och länka mot app-targeten."
            #endif
        }
    }
}

struct FText: View {
    @StateObject private var vm = FTextViewModel()

    var body: some View {
        VStack(spacing: 18) {
            Text("Firebase snabbtest")
                .font(.title2).bold()

            Text(vm.status)
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "pencil.and.outline")
                TextField("Meddelande", text: $vm.input)
                    .textInputAutocapitalization(.sentences)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.horizontal)

            Button {
                vm.writeAndRead()
            } label: {
                Label("Skriv & Läs", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)

            if !vm.fetched.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hämtat värde")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vm.fetched)
                        .font(.body)
                        .monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .onAppear {
            if vm.fetched.isEmpty { vm.writeAndRead() }
        }
    }
}

struct FText_Previews: PreviewProvider {
    static var previews: some View {
        FText()
            .preferredColorScheme(.dark)
            .previewDisplayName("FText – Firebase test")
    }
}
