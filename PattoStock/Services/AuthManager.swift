import Foundation
import FirebaseCore
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    var currentUserId: String?
    var isSignedIn: Bool = false
    var isAnonymous: Bool = false
    var userEmail: String?
    var errorMessage: String?

    private(set) var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUserId = user?.uid
                self?.isSignedIn = user != nil
                self?.isAnonymous = user?.isAnonymous ?? false
                self?.userEmail = user?.email
            }
        }
    }

    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)
    }

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

        guard let nonce = currentNonce else {
            errorMessage = "nonceが見つかりません。もう一度お試しください。"
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
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

    // MARK: - Private

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
