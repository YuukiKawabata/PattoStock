import SwiftUI

struct ShoppingListView: View {
    @Environment(FirestoreManager.self) private var manager

    @State private var checkedItems: Set<String> = []

    private var shoppingItems: [InventoryItem] {
        manager.needsRestockItems
    }

    private var shareText: String {
        let items = shoppingItems.map { "- \($0.name) x\($0.restockAmount)" }
        return "買い物リスト:\n" + items.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if shoppingItems.isEmpty {
                    ContentUnavailableView(
                        "買い物なし",
                        systemImage: "cart",
                        description: Text("在庫は十分です")
                    )
                } else {
                    List {
                        Section {
                            ForEach(shoppingItems) { item in
                                shoppingRow(item: item)
                            }
                        } header: {
                            Text("補充が必要なアイテム（\(shoppingItems.count)件）")
                        }
                    }
                }
            }
            .navigationTitle("買い物リスト")
            .toolbar {
                if !shoppingItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func shoppingRow(item: InventoryItem) -> some View {
        HStack {
            Button {
                toggleCheck(item)
            } label: {
                Image(systemName: isChecked(item) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked(item) ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(isChecked(item))
                    .foregroundStyle(isChecked(item) ? .secondary : .primary)
                Text("\(item.category) ・ 補充: \(item.restockAmount)個")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("残り\(item.currentCount)個")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.statusColor.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private func isChecked(_ item: InventoryItem) -> Bool {
        guard let id = item.id else { return false }
        return checkedItems.contains(id)
    }

    private func toggleCheck(_ item: InventoryItem) {
        guard let id = item.id else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if checkedItems.contains(id) {
            checkedItems.remove(id)
        } else {
            checkedItems.insert(id)
            Task {
                try? await manager.restockItem(item)
            }
        }
    }
}
