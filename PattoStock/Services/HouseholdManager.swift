import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class HouseholdManager {
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
            currentHousehold = household
            currentHousehold?.id = ref.documentID
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
        } catch {
            errorMessage = "世帯への参加に失敗しました: \(error.localizedDescription)"
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

    /// Firestore path for the current scope (household or user)
    var itemsCollectionPath: String? {
        if let householdId = currentHousehold?.id {
            return "households/\(householdId)/items"
        }
        return nil
    }
}
