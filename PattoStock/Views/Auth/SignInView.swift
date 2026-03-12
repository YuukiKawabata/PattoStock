import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authManager = AuthManager.shared
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)
                    Text("Patto")
                        .font(.largeTitle.bold())
                    Text("サインインしてデータを安全に保存")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        authManager.prepareRequest(request)
                    } onCompletion: { result in
                        handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)

                    Button("あとで") {
                        Task {
                            try? await authManager.signInAnonymously()
                            dismiss()
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            Task {
                do {
                    try await authManager.signInWithApple(authorization: auth)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
        }
    }
}
