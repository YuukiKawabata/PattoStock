import SwiftUI

struct StockListView: View {
    @Environment(FirestoreManager.self) private var manager

    @State private var showingAddSheet = false
    @State private var editingItem: InventoryItem?
    @State private var searchText = ""
    @State private var selectedCategory: String?

    private var filteredItems: [InventoryItem] {
        manager.items.filter { item in
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    private var outOfStock: [InventoryItem] { filteredItems.filter { $0.status == .outOfStock } }
    private var lowStock: [InventoryItem] { filteredItems.filter { $0.status == .low } }
    private var inStock: [InventoryItem] { filteredItems.filter { $0.status == .inStock } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !manager.categories.isEmpty {
                    categoryFilter
                }

                List {
                    stockSection(items: outOfStock, label: "在庫切れ", icon: "exclamationmark.triangle.fill", color: .red)
                    stockSection(items: lowStock, label: "残りわずか", icon: "exclamationmark.circle.fill", color: .yellow)
                    stockSection(items: inStock, label: "在庫あり", icon: "checkmark.circle.fill", color: .green)

                    if filteredItems.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "アイテムがありません" : "見つかりません",
                            systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                            description: Text(searchText.isEmpty ? "右上の＋ボタンから追加してください" : "「\(searchText)」に一致するアイテムはありません")
                        )
                    }
                }
            }
            .navigationTitle("PattoStock")
            .searchable(text: $searchText, prompt: "商品名を検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ItemFormSheet()
            }
            .sheet(item: $editingItem) { item in
                ItemFormSheet(editingItem: item)
            }
            .alert("エラー", isPresented: .init(
                get: { manager.errorMessage != nil },
                set: { if !$0 { manager.clearError() } }
            )) {
                Button("OK") { manager.clearError() }
            } message: {
                Text(manager.errorMessage ?? "")
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "すべて", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(manager.categories, id: \.self) { category in
                    FilterChip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func stockSection(items: [InventoryItem], label: String, icon: String, color: Color) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    StockRowView(item: item) {
                        editingItem = item
                    }
                }
            } header: {
                Label(label, systemImage: icon)
                    .foregroundStyle(color)
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
