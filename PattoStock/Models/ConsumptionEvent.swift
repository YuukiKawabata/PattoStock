import Foundation
import FirebaseFirestore

struct ConsumptionEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var itemId: String
    var itemName: String
    var category: String
    var quantity: Int
    @ServerTimestamp var date: Date?
}
