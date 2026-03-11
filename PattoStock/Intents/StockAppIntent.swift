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

private var consumptionCollectionPath: String {
    if let uid = AuthManager.shared.currentUserId {
        return "users/\(uid)/consumptionEvents"
    }
    return "consumptionEvents"
}

// MARK: - Category AppEnum

enum ItemCategoryAppEnum: String, AppEnum {
    case food = "食品"
    case beverage = "飲料"
    case daily = "日用品"
    case detergent = "洗剤"
    case hygiene = "衛生用品"
    case other = "その他"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "カテゴリ"

    static var caseDisplayRepresentations: [ItemCategoryAppEnum: DisplayRepresentation] = [
        .food: "食品",
        .beverage: "飲料",
        .daily: "日用品",
        .detergent: "洗剤",
        .hygiene: "衛生用品",
        .other: "その他"
    ]
}

// MARK: - Entity

struct InventoryItemEntity: AppEntity {
    static var defaultQuery = InventoryItemQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "在庫アイテム"

    var id: String
    var name: String
    var currentCount: Int
    var category: String
    var threshold: Int
    var restockAmount: Int

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
                results.append(InventoryItemEntity(
                    id: id,
                    name: name,
                    currentCount: count,
                    category: data["category"] as? String ?? "その他",
                    threshold: data["threshold"] as? Int ?? 2,
                    restockAmount: data["restockAmount"] as? Int ?? 1
                ))
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
            return InventoryItemEntity(
                id: doc.documentID,
                name: name,
                currentCount: count,
                category: data["category"] as? String ?? "その他",
                threshold: data["threshold"] as? Int ?? 2,
                restockAmount: data["restockAmount"] as? Int ?? 1
            )
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

        // 消費イベントを記録
        let eventData: [String: Any] = [
            "itemId": item.id,
            "itemName": item.name,
            "category": item.category,
            "quantity": quantity,
            "date": FieldValue.serverTimestamp()
        ]
        try await db.collection(consumptionCollectionPath).addDocument(data: eventData)

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
                let restockAmount = data["restockAmount"] as? Int ?? 1
                return "\(name)（残り\(count)個、\(restockAmount)個買う）"
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

// MARK: - Get Item Status Intent

struct GetItemStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "アイテムの状態を確認"
    static var description: IntentDescription = "特定アイテムの在庫数とステータスを確認します"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "商品")
    var item: InventoryItemEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()
        let doc = try await db.collection(itemsCollectionPath).document(item.id).getDocument()
        let data = doc.data() ?? [:]

        let count = data["currentCount"] as? Int ?? item.currentCount
        let threshold = data["threshold"] as? Int ?? item.threshold

        let statusLabel: String
        if count <= 0 {
            statusLabel = "在庫切れ"
        } else if count <= threshold {
            statusLabel = "残りわずか"
        } else {
            statusLabel = "在庫あり"
        }

        return .result(dialog: "\(item.name)は残り\(count)個です。\(statusLabel)。")
    }
}

// MARK: - Get Category Stock Intent

struct GetCategoryStockIntent: AppIntent {
    static var title: LocalizedStringResource = "カテゴリ別在庫確認"
    static var description: IntentDescription = "指定カテゴリの全アイテムと在庫数を読み上げます"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "カテゴリ")
    var category: ItemCategoryAppEnum

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()
        let snapshot = try await db.collection(itemsCollectionPath)
            .whereField("category", isEqualTo: category.rawValue)
            .getDocuments()

        let items = snapshot.documents.compactMap { doc -> String? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let count = data["currentCount"] as? Int else { return nil }
            return "\(name)（\(count)個）"
        }

        if items.isEmpty {
            return .result(dialog: "\(category.rawValue)の在庫はありません。")
        }

        let list = items.joined(separator: "、")
        return .result(dialog: "\(category.rawValue)の在庫: \(list)")
    }
}

// MARK: - Get Predictions Intent

struct GetPredictionsIntent: AppIntent {
    static var title: LocalizedStringResource = "在庫予測を確認"
    static var description: IntentDescription = "3日以内に切れそうなアイテムを読み上げます"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()

        let itemsSnapshot = try await db.collection(itemsCollectionPath).getDocuments()
        let items: [InventoryItem] = itemsSnapshot.documents.compactMap { try? $0.data(as: InventoryItem.self) }

        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let eventsSnapshot = try await db.collection(consumptionCollectionPath)
            .whereField("date", isGreaterThan: Timestamp(date: startDate))
            .order(by: "date", descending: true)
            .getDocuments()
        let events: [ConsumptionEvent] = eventsSnapshot.documents.compactMap { try? $0.data(as: ConsumptionEvent.self) }

        let predictions = await MainActor.run {
            let engine = PredictionEngine()
            return engine.predictAll(items: items, events: events)
        }

        let urgent = predictions.filter { $0.isUrgent }

        if urgent.isEmpty {
            return .result(dialog: "3日以内に切れそうなものはありません。")
        }

        let list = urgent.map { "\($0.itemName)（\($0.predictionText)）" }.joined(separator: "、")
        return .result(dialog: "3日以内に切れそうなもの: \(list)")
    }
}

// MARK: - Restock Item Intent

struct RestockItemIntent: AppIntent {
    static var title: LocalizedStringResource = "まとめて補充"
    static var description: IntentDescription = "アイテムの既定補充数を一括補充します"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "商品")
    var item: InventoryItemEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()

        // 最新のrestockAmountを取得
        let doc = try await db.collection(itemsCollectionPath).document(item.id).getDocument()
        let data = doc.data() ?? [:]
        let restockAmount = data["restockAmount"] as? Int ?? item.restockAmount

        try await db.collection(itemsCollectionPath).document(item.id).updateData([
            "currentCount": FieldValue.increment(Int64(restockAmount)),
            "lastUpdated": FieldValue.serverTimestamp()
        ])

        return .result(dialog: "\(item.name)を\(restockAmount)個補充しました")
    }
}

// MARK: - Add New Item Intent

struct AddNewItemIntent: AppIntent {
    static var title: LocalizedStringResource = "新しいアイテムを追加"
    static var description: IntentDescription = "新しいアイテムを在庫に登録します"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "名前")
    var name: String

    @Parameter(title: "カテゴリ")
    var category: ItemCategoryAppEnum

    @Parameter(title: "初期在庫数", default: 1)
    var initialCount: Int

    @Parameter(title: "しきい値", default: 2)
    var threshold: Int

    @Parameter(title: "補充数量", default: 1)
    var restockAmount: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await ensureFirebaseConfigured()
        let db = Firestore.firestore()

        let itemData: [String: Any] = [
            "name": name,
            "currentCount": initialCount,
            "threshold": threshold,
            "category": category.rawValue,
            "restockAmount": restockAmount,
            "lastUpdated": FieldValue.serverTimestamp()
        ]

        try await db.collection(itemsCollectionPath).addDocument(data: itemData)

        return .result(dialog: "\(name)を追加しました（カテゴリ: \(category.rawValue)、在庫: \(initialCount)個）")
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

        AppShortcut(
            intent: GetItemStatusIntent(),
            phrases: [
                "\(.applicationName)で\(\.$item)の状態を教えて",
                "\(.applicationName)の\(\.$item)はどう？"
            ],
            shortTitle: "アイテムの状態",
            systemImageName: "info.circle"
        )

        AppShortcut(
            intent: GetCategoryStockIntent(),
            phrases: [
                "\(.applicationName)の\(\.$category)の在庫は？",
                "\(.applicationName)で\(\.$category)を確認"
            ],
            shortTitle: "カテゴリ別在庫",
            systemImageName: "folder"
        )

        AppShortcut(
            intent: GetPredictionsIntent(),
            phrases: [
                "\(.applicationName)でもうすぐ切れるものは？",
                "\(.applicationName)の在庫予測を教えて"
            ],
            shortTitle: "在庫予測",
            systemImageName: "chart.line.downtrend.xyaxis"
        )

        AppShortcut(
            intent: RestockItemIntent(),
            phrases: [
                "\(.applicationName)で\(\.$item)をまとめて補充",
                "\(.applicationName)の\(\.$item)を一括補充"
            ],
            shortTitle: "まとめて補充",
            systemImageName: "arrow.clockwise.circle"
        )

        AppShortcut(
            intent: AddNewItemIntent(),
            phrases: [
                "\(.applicationName)に新しいアイテムを登録して",
                "\(.applicationName)でアイテムを新規追加"
            ],
            shortTitle: "新規アイテム追加",
            systemImageName: "plus.rectangle"
        )
    }
}
