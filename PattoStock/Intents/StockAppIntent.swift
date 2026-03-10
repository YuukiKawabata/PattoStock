import AppIntents
import FirebaseCore
@preconcurrency import FirebaseFirestore

@MainActor
private func ensureFirebaseConfigured() {
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
}

private var itemsCollectionPath: String {
    if let uid = AuthManager.shared.currentUserId {
        return "users/\(uid)/items"
    }
    return "items"
}

// MARK: - Entity

struct InventoryItemEntity: AppEntity {
    static var defaultQuery = InventoryItemQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "在庫アイテム"

    var id: String
    var name: String
    var currentCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "残り \(currentCount) 個")
    }
}

// MARK: - Query

struct InventoryItemQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [InventoryItemEntity] {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()
        var results: [InventoryItemEntity] = []
        for id in identifiers {
            let doc = try await db.collection(itemsCollectionPath).document(id).getDocument()
            let data = doc.data() ?? [:]
            if let name = data["name"] as? String,
               let count = data["currentCount"] as? Int {
                results.append(InventoryItemEntity(id: id, name: name, currentCount: count))
            }
        }
        return results
    }

    func suggestedEntities() async throws -> [InventoryItemEntity] {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()
        let snapshot = try await db.collection(itemsCollectionPath).getDocuments()
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let count = data["currentCount"] as? Int else { return nil }
            return InventoryItemEntity(id: doc.documentID, name: name, currentCount: count)
        }
    }
}

// MARK: - Reduce Stock Intent

struct ReduceStockIntent: AppIntent {
    static var title: LocalizedStringResource = "在庫を減らす"
    static var description: IntentDescription = "指定した商品の在庫を減らします"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "商品")
    var item: InventoryItemEntity

    @Parameter(title: "数量", default: 1)
    var quantity: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()
        try await db.collection(itemsCollectionPath).document(item.id).updateData([
            "currentCount": FieldValue.increment(Int64(-quantity)),
            "lastUpdated": FieldValue.serverTimestamp()
        ])
        return .result(dialog: "\(item.name)を\(quantity)個減らしました")
    }
}

// MARK: - Add Stock Intent

struct AddStockIntent: AppIntent {
    static var title: LocalizedStringResource = "在庫を補充する"
    static var description: IntentDescription = "指定した商品の在庫を補充します"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "商品")
    var item: InventoryItemEntity

    @Parameter(title: "数量", default: 1)
    var quantity: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()
        try await db.collection(itemsCollectionPath).document(item.id).updateData([
            "currentCount": FieldValue.increment(Int64(quantity)),
            "lastUpdated": FieldValue.serverTimestamp()
        ])
        return .result(dialog: "\(item.name)を\(quantity)個補充しました")
    }
}

// MARK: - Check Stock Intent

struct CheckStockIntent: AppIntent {
    static var title: LocalizedStringResource = "買うものを確認"
    static var description: IntentDescription = "在庫が少ないアイテムの一覧を読み上げます"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()
        let snapshot = try await db.collection(itemsCollectionPath).getDocuments()

        let lowItems = snapshot.documents.compactMap { doc -> String? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let count = data["currentCount"] as? Int,
                  let threshold = data["threshold"] as? Int else { return nil }
            if count <= threshold {
                return "\(name)（残り\(count)個）"
            }
            return nil
        }

        if lowItems.isEmpty {
            return .result(dialog: "買い足すものはありません。すべて在庫があります。")
        }

        let list = lowItems.joined(separator: "、")
        return .result(dialog: "買い足しが必要なのは: \(list)")
    }
}

// MARK: - Shortcuts

struct PattoStockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReduceStockIntent(),
            phrases: [
                "\(.applicationName)で\(\.$item)を減らして",
                "\(.applicationName)で\(\.$item)を使った",
                "\(.applicationName)の\(\.$item)を消費"
            ],
            shortTitle: "在庫を減らす",
            systemImageName: "minus.circle"
        )

        AppShortcut(
            intent: AddStockIntent(),
            phrases: [
                "\(.applicationName)で\(\.$item)を補充",
                "\(.applicationName)に\(\.$item)を追加"
            ],
            shortTitle: "在庫を補充",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: CheckStockIntent(),
            phrases: [
                "\(.applicationName)で買うものある？",
                "\(.applicationName)の在庫を確認",
                "\(.applicationName)で足りないものは？"
            ],
            shortTitle: "買うものを確認",
            systemImageName: "cart"
        )
    }
}
