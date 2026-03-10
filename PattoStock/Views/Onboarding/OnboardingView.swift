import SwiftUI

struct OnboardingView: View {
    @Environment(FirestoreManager.self) private var manager
    @Binding var isComplete: Bool

    @State private var currentPage = 0
    @State private var selectedPresets: Set<String> = []

    private let presets: [(name: String, category: String, threshold: Int)] = [
        ("トイレットペーパー", "日用品", 2),
        ("ティッシュ", "日用品", 2),
        ("シャンプー", "衛生用品", 1),
        ("ボディソープ", "衛生用品", 1),
        ("洗濯洗剤", "洗剤", 1),
        ("食器用洗剤", "洗剤", 1),
        ("牛乳", "飲料", 1),
        ("パン", "食品", 1),
        ("卵", "食品", 1),
        ("米", "食品", 1),
        ("歯磨き粉", "衛生用品", 1),
        ("ゴミ袋", "日用品", 1),
    ]

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            presetsPage.tag(1)
            notificationPage.tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
            Text("PattoStock へようこそ")
                .font(.largeTitle.bold())
            Text("家の在庫をパッと確認、\nパッと管理できるアプリです")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            nextButton { currentPage = 1 }
        }
        .padding()
    }

    private var presetsPage: some View {
        VStack(spacing: 16) {
            Text("よく使うアイテムを追加")
                .font(.title2.bold())
                .padding(.top, 40)
            Text("あとからいつでも追加・変更できます")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(presets, id: \.name) { preset in
                        PresetChip(
                            name: preset.name,
                            category: preset.category,
                            isSelected: selectedPresets.contains(preset.name)
                        ) {
                            if selectedPresets.contains(preset.name) {
                                selectedPresets.remove(preset.name)
                            } else {
                                selectedPresets.insert(preset.name)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            nextButton {
                Task {
                    await addSelectedPresets()
                    currentPage = 2
                }
            }
        }
        .padding()
    }

    private var notificationPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("在庫切れをお知らせ")
                .font(.title2.bold())
            Text("在庫が少なくなったら\n通知でお知らせします")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        _ = await NotificationManager.shared.requestAuthorization()
                        completeOnboarding()
                    }
                } label: {
                    Text("通知を許可する")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("あとで") {
                    completeOnboarding()
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func nextButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("次へ")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func addSelectedPresets() async {
        for preset in presets where selectedPresets.contains(preset.name) {
            let item = InventoryItem(
                name: preset.name,
                currentCount: 0,
                threshold: preset.threshold,
                category: preset.category
            )
            try? await manager.addItem(item)
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation { isComplete = true }
    }
}

private struct PresetChip: View {
    let name: String
    let category: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
