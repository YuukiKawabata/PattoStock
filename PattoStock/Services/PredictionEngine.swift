import Foundation

struct StockPrediction {
    let itemName: String
    let daysUntilEmpty: Int?
    let averageDailyConsumption: Double

    var predictionText: String {
        guard let days = daysUntilEmpty else { return "データ不足" }
        if days <= 0 { return "在庫切れ" }
        if days == 1 { return "明日切れそう" }
        if days <= 3 { return "あと約\(days)日で切れそう" }
        if days <= 7 { return "あと約\(days)日" }
        return "十分な在庫あり"
    }

    var isUrgent: Bool {
        guard let days = daysUntilEmpty else { return false }
        return days <= 3
    }
}

@MainActor
final class PredictionEngine {
    func predict(item: InventoryItem, events: [ConsumptionEvent]) -> StockPrediction {
        let itemEvents = events.filter { $0.itemId == item.id }

        guard itemEvents.count >= 2,
              let earliest = itemEvents.compactMap(\.date).min(),
              let latest = itemEvents.compactMap(\.date).max() else {
            return StockPrediction(itemName: item.name, daysUntilEmpty: nil, averageDailyConsumption: 0)
        }

        let daySpan = max(Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1, 1)
        let totalConsumed = itemEvents.reduce(0) { $0 + $1.quantity }
        let avgDaily = Double(totalConsumed) / Double(daySpan)

        guard avgDaily > 0 else {
            return StockPrediction(itemName: item.name, daysUntilEmpty: nil, averageDailyConsumption: 0)
        }

        let daysLeft = Int(Double(item.currentCount) / avgDaily)

        return StockPrediction(
            itemName: item.name,
            daysUntilEmpty: daysLeft,
            averageDailyConsumption: avgDaily
        )
    }

    func predictAll(items: [InventoryItem], events: [ConsumptionEvent]) -> [StockPrediction] {
        items.map { predict(item: $0, events: events) }
            .sorted { ($0.daysUntilEmpty ?? Int.max) < ($1.daysUntilEmpty ?? Int.max) }
    }
}
