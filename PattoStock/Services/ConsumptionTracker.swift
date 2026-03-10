import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class ConsumptionTracker {
    var events: [ConsumptionEvent] = []

    private var db: Firestore { Firestore.firestore() }

    private var collectionPath: String {
        if let uid = AuthManager.shared.currentUserId {
            return "users/\(uid)/consumptionEvents"
        }
        return "consumptionEvents"
    }

    func recordConsumption(item: InventoryItem, quantity: Int) async {
        guard let itemId = item.id else { return }
        let event = ConsumptionEvent(
            itemId: itemId,
            itemName: item.name,
            category: item.category,
            quantity: quantity
        )
        try? db.collection(collectionPath).addDocument(from: event)
    }

    func loadEvents(days: Int = 30) async {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        do {
            let snapshot = try await db.collection(collectionPath)
                .whereField("date", isGreaterThan: Timestamp(date: startDate))
                .order(by: "date", descending: true)
                .getDocuments()
            events = snapshot.documents.compactMap { try? $0.data(as: ConsumptionEvent.self) }
        } catch {
            events = []
        }
    }

    struct CategoryConsumption: Identifiable {
        let id = UUID()
        let category: String
        let totalQuantity: Int
    }

    var consumptionByCategory: [CategoryConsumption] {
        let grouped = Dictionary(grouping: events, by: \.category)
        return grouped.map { category, events in
            CategoryConsumption(
                category: category,
                totalQuantity: events.reduce(0) { $0 + $1.quantity }
            )
        }.sorted { $0.totalQuantity > $1.totalQuantity }
    }

    struct DailyConsumption: Identifiable {
        let id = UUID()
        let date: Date
        let totalQuantity: Int
    }

    var dailyConsumption: [DailyConsumption] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.date ?? Date())
        }
        return grouped.map { date, events in
            DailyConsumption(date: date, totalQuantity: events.reduce(0) { $0 + $1.quantity })
        }.sorted { $0.date < $1.date }
    }
}
