import SwiftUI
import FirebaseCore
import FirebaseAuth
import AppIntents

@main
struct PattoApp: App {
    @State private var firestoreManager = FirestoreManager()
    @State private var householdManager = HouseholdManager.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(firestoreManager)
                .environment(householdManager)
                .task {
                    PattoShortcuts.updateAppShortcutParameters()
                    _ = await NotificationManager.shared.requestAuthorization()

                    // Sign in anonymously if not signed in
                    if !AuthManager.shared.isSignedIn {
                        try? await AuthManager.shared.signInAnonymously()
                    }

                    // Load household first, then start listening on the correct path
                    await householdManager.loadCurrentHousehold()
                    firestoreManager.startListening()
                }
        }
    }
}
