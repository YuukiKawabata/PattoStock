import Foundation
import FirebaseCore
import FirebaseAuth
import AuthenticationServices

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    var currentUserId: String? { Auth.auth().currentUser?.uid }
    var isSignedIn: Bool { Auth.auth().currentUser != nil }
    var isAnonymous: Bool { Auth.auth().currentUser?.isAnonymous ?? false }
    var userEmail: String? { Auth.auth().currentUser?.email }
    var errorMessage: String?

    private init() {}

    func signInAnonymously() async throws {
        do {
            try await Auth.auth().signInAnonymously()
        } catch {
            errorMessage = "匿名ログインに失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func linkWithApple(credential: AuthCredential) async throws {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.link(with: credential)
        } catch {
            errorMessage = "アカウント連携に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            errorMessage = "Apple認証情報の取得に失敗しました"
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nil,
            fullName: appleIDCredential.fullName
        )

        do {
            if isAnonymous {
                try await linkWithApple(credential: credential)
            } else {
                try await Auth.auth().signIn(with: credential)
            }
        } catch {
            errorMessage = "サインインに失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = "サインアウトに失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.delete()
        } catch {
            errorMessage = "アカウント削除に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
