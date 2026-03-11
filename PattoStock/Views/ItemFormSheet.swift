import SwiftUI

struct ItemFormSheet: View {
    @Environment(FirestoreManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    let editingItem: InventoryItem?

    @State private var name: String
    @State private var category: String
    @State private var currentCount: Int
    @State private var threshold: Int
    @State private var restockAmount: Int
    @State private var barcode: String
    @State private var errorMessage: String?
    @State private var showBarcodeScanner = false
    @State private var showDeleteConfirmation = false

    private let categories = ["食品", "飲料", "日用品", "洗剤", "衛生用品", "その他"]

    var isEditing: Bool { editingItem != nil }

    init(editingItem: InventoryItem? = nil) {
        self.editingItem = editingItem
        _name = State(initialValue: editingItem?.name ?? "")
        _category = State(initialValue: editingItem?.category ?? "食品")
        _currentCount = State(initialValue: editingItem?.currentCount ?? 1)
        _threshold = State(initialValue: editingItem?.threshold ?? 2)
        _restockAmount = State(initialValue: editingItem?.restockAmount ?? 1)
        _barcode = State(initialValue: editingItem?.barcode ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("商品情報") {
                    TextField("商品名", text: $name)

                    Picker("カテゴリ", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    HStack {
                        TextField("バーコード", text: $barcode)
                            .keyboardType(.numberPad)
                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                }

                Section("数量") {
                    Stepper("現在の在庫: \(currentCount)", value: $currentCount, in: 0...999)
                    Stepper("通知しきい値: \(threshold)", value: $threshold, in: 0...999)
                    Stepper("補充数量: \(restockAmount)", value: $restockAmount, in: 1...999)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if isEditing {
                    Section {
                        Button("このアイテムを削除", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "アイテム編集" : "アイテム追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "追加") {
                        saveItem()
                    }
                    .disabled(name.isEmpty || category.isEmpty)
                }
            }
            .confirmationDialog("「\(name)」を削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    guard let id = editingItem?.id else { return }
                    Task {
                        do {
                            try await manager.deleteItem(id: id)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView { scannedBarcode, productInfo in
                    barcode = scannedBarcode
                    if let info = productInfo {
                        if name.isEmpty { name = info.name }
                        if let cat = info.category { category = cat }
                    }
                }
            }
        }
    }

    private func saveItem() {
        Task {
            do {
                if var existing = editingItem {
                    existing.name = name
                    existing.category = category
                    existing.currentCount = currentCount
                    existing.threshold = threshold
                    existing.restockAmount = restockAmount
                    existing.barcode = barcode.isEmpty ? nil : barcode
                    try await manager.updateItem(existing)
                } else {
                    let item = InventoryItem(
                        name: name,
                        currentCount: currentCount,
                        threshold: threshold,
                        category: category,
                        restockAmount: restockAmount,
                        barcode: barcode.isEmpty ? nil : barcode
                    )
                    try await manager.addItem(item)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
