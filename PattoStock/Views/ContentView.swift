import SwiftUI

struct ContentView: View {
    @Environment(FirestoreManager.self) private var manager
    @State private var selectedTab = 0
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        if hasCompletedOnboarding {
            TabView(selection: $selectedTab) {
                Tab("在庫", systemImage: "shippingbox.fill", value: 0) {
                    StockListView()
                }

                Tab("買い物", systemImage: "cart.fill", value: 1) {
                    ShoppingListView()
                }
                .badge(manager.needsRestockItems.count)

                Tab("トレンド", systemImage: "chart.bar.fill", value: 2) {
                    TrendsView()
                }

                Tab("設定", systemImage: "gearshape.fill", value: 3) {
                    SettingsView()
                }
            }
        } else {
            OnboardingView(isComplete: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .environment(FirestoreManager())
}
