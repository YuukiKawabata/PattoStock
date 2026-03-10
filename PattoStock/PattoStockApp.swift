import SwiftUI
import FirebaseCore
import FirebaseAuth
import AppIntents

@main
struct PattoStockApp: App {
    @State private var firestoreManager = FirestoreManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(firestoreManager)
                .onAppear {
                    firestoreManager.startListening()
                }
                .task {
                    PattoStockShortcuts.updateAppShortcutParameters()
                    _ = await NotificationManager.shared.requestAuthorization()

                    // Sign in anonymously if not signed in
                    if !AuthManager.shared.isSignedIn {
                        try? await AuthManager.shared.signInAnonymously()
                    }
                }
        }
    }
}
