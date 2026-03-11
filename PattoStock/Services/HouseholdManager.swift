import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class HouseholdManager {
    static let shared = HouseholdManager()
    private init() {}

    var currentHousehold: Household?
    var errorMessage: String?

    private var db: Firestore { Firestore.firestore() }

    func createHousehold(name: String) async throws {
        guard let uid = AuthManager.shared.currentUserId else { return }
        let household = Household(name: name, ownerUid: uid, memberUids: [uid])
        do {
            let ref = try db.collection("households").addDocument(from: household)
            try await db.collection("users").document(uid).setData(
                ["householdId": ref.documentID], merge: true
            )
            var created = household
            created.id = ref.documentID
            currentHousehold = created
        } catch {
            errorMessage = "世帯の作成に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func joinHousehold(inviteCode: String) async throws {
        guard let uid = AuthManager.shared.currentUserId else { return }
        let docRef = db.collection("households").document(inviteCode)
        do {
            try await docRef.updateData([
                "memberUids": FieldValue.arrayUnion([uid])
            ])
            try await db.collection("users").document(uid).setData(
                ["householdId": inviteCode], merge: true
            )
            let doc = try await docRef.getDocument()
            currentHousehold = try doc.data(as: Household.self)
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 5 {
                errorMessage = "招待コードが見つかりません。コードを確認してください。"
            } else {
                errorMessage = "世帯への参加に失敗しました: \(error.localizedDescription)"
            }
            throw error
        }
    }

    func loadCurrentHousehold() async {
        guard let uid = AuthManager.shared.currentUserId else { return }
        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            guard let householdId = userDoc.data()?["householdId"] as? String else { return }
            let doc = try await db.collection("households").document(householdId).getDocument()
            currentHousehold = try doc.data(as: Household.self)
        } catch {
            currentHousehold = nil
        }
    }

    func leaveHousehold() async throws {
        guard let uid = AuthManager.shared.currentUserId,
              let householdId = currentHousehold?.id else { return }
        do {
            try await db.collection("households").document(householdId).updateData([
                "memberUids": FieldValue.arrayRemove([uid])
            ])
            try await db.collection("users").document(uid).updateData([
                "householdId": FieldValue.delete()
            ])
            currentHousehold = nil
        } catch {
            errorMessage = "世帯からの退出に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    var itemsCollectionPath: String {
        if let householdId = currentHousehold?.id {
            return "households/\(householdId)/items"
        }
        if let uid = AuthManager.shared.currentUserId {
            return "users/\(uid)/items"
        }
        return "items"
    }

    var consumptionEventsCollectionPath: String {
        if let householdId = currentHousehold?.id {
            return "households/\(householdId)/consumptionEvents"
        }
        if let uid = AuthManager.shared.currentUserId {
            return "users/\(uid)/consumptionEvents"
        }
        return "consumptionEvents"
    }
}
