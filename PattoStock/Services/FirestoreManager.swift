import Foundation
import FirebaseFirestore
import SwiftUI

@Observable
@MainActor
final class FirestoreManager {
    var items: [InventoryItem] = []
    var errorMessage: String?

    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?

    private var collectionPath: String {
        if let uid = AuthManager.shared.currentUserId {
            return "users/\(uid)/items"
        }
        return "items"
    }

    var outOfStockItems: [InventoryItem] {
        items.filter { $0.status == .outOfStock }
    }

    var lowStockItems: [InventoryItem] {
        items.filter { $0.status == .low }
    }

    var inStockItems: [InventoryItem] {
        items.filter { $0.status == .inStock }
    }

    var needsRestockItems: [InventoryItem] {
        items.filter { $0.needsRestock }
    }

    var categories: [String] {
        Array(Set(items.map(\.category))).sorted()
    }

    func startListening() {
        stopListening()
        listener = db.collection(collectionPath)
            .order(by: "lastUpdated", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = "データの取得に失敗しました: \(error.localizedDescription)"
                    return
                }
                guard let snapshot else { return }

                let oldItems = self.items
                let newItems = snapshot.documents.compactMap { doc in
                    try? doc.data(as: InventoryItem.self)
                }
                withAnimation {
                    self.items = newItems
                }

                self.checkStatusChanges(oldItems: oldItems, newItems: self.items)
                self.syncWidgetData()
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addItem(_ item: InventoryItem) async throws {
        do {
            _ = try db.collection(collectionPath).addDocument(from: item)
        } catch {
            errorMessage = "追加に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func updateItem(_ item: InventoryItem) async throws {
        guard let id = item.id else { return }
        do {
            try db.collection(collectionPath).document(id).setData(from: item, merge: true)
        } catch {
            errorMessage = "更新に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func deleteItem(id: String) async throws {
        do {
            try await db.collection(collectionPath).document(id).delete()
        } catch {
            errorMessage = "削除に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func updateCount(itemId: String, delta: Int) async throws {
        do {
            try await db.collection(collectionPath).document(itemId).updateData([
                "currentCount": FieldValue.increment(Int64(delta)),
                "lastUpdated": FieldValue.serverTimestamp()
            ])
        } catch {
            errorMessage = "数量の更新に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func restockItem(_ item: InventoryItem) async throws {
        guard let id = item.id else { return }
        try await updateCount(itemId: id, delta: item.restockAmount)
    }

    func clearError() {
        errorMessage = nil
    }

    func syncWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group.com.yuuki.PattoStock") else { return }
        let shoppingItems = needsRestockItems.map { item in
            WidgetShoppingItem(
                id: item.id ?? "",
                name: item.name,
                currentCount: item.currentCount,
                restockAmount: item.restockAmount
            )
        }
        if let data = try? JSONEncoder().encode(shoppingItems) {
            defaults.set(data, forKey: "shoppingList")
        }
    }

    private struct WidgetShoppingItem: Codable {
        let id: String
        let name: String
        let currentCount: Int
        let restockAmount: Int
    }

    private func checkStatusChanges(oldItems: [InventoryItem], newItems: [InventoryItem]) {
        let oldDict = Dictionary(uniqueKeysWithValues: oldItems.compactMap { item in
            item.id.map { ($0, item.status) }
        })

        for newItem in newItems {
            guard let id = newItem.id, let oldStatus = oldDict[id] else { continue }
            if oldStatus != newItem.status &&
                (newItem.status == .low || newItem.status == .outOfStock) {
                NotificationManager.shared.sendLowStockNotification(for: newItem)
            }
        }
    }
}
