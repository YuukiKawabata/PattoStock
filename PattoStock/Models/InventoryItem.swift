import SwiftUI
import FirebaseFirestore

struct InventoryItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var currentCount: Int
    var threshold: Int
    var category: String
    var restockAmount: Int = 1
    var barcode: String?
    @ServerTimestamp var lastUpdated: Date?

    var status: StockStatus {
        if currentCount <= 0 {
            return .outOfStock
        } else if currentCount <= threshold {
            return .low
        } else {
            return .inStock
        }
    }

    var statusColor: Color {
        status.color
    }

    var needsRestock: Bool {
        status == .outOfStock || status == .low
    }
}

enum StockStatus: String, Codable {
    case outOfStock
    case low
    case inStock

    var color: Color {
        switch self {
        case .outOfStock: .red
        case .low: .yellow
        case .inStock: .green
        }
    }

    var label: String {
        switch self {
        case .outOfStock: "在庫切れ"
        case .low: "残りわずか"
        case .inStock: "在庫あり"
        }
    }
}
