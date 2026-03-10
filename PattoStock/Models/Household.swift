import Foundation
import FirebaseFirestore

struct Household: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var ownerUid: String
    var memberUids: [String]
    @ServerTimestamp var createdAt: Date?

    var inviteCode: String {
        id ?? ""
    }
}
