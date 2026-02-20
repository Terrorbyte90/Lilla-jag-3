//
//  Lilla_jag_3App.swift
//  Lilla jag 3
//
//  Created by Ted Svärd on 2025-07-13.
//

import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth

// AppDelegate för Firebase-initialisering
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    private var handle: AuthStateDidChangeListenerHandle?

    func listenToAuthState() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = user != nil
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

@main
struct Lilla_jag_3App: App {
    // Knyt AppDelegate till SwiftUI-livscykeln
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoggedIn {
                    ContentView()
                } else {
                    Inlogg()
                }
            }
            .onAppear {
                authVM.listenToAuthState()
            }
            .preferredColorScheme(.dark)
        }
    }
}
