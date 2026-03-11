import SwiftUI

struct FamilySharingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FirestoreManager.self) private var firestoreManager
    @Environment(HouseholdManager.self) private var householdManager

    @State private var authManager = AuthManager.shared
    @State private var mode: Mode = .menu
    @State private var householdName: String = ""
    @State private var inviteCode: String = ""
    @State private var isLoading = false
    @State private var showLeaveConfirmation = false
    @State private var showCopiedFeedback = false
    @State private var showSignIn = false

    enum Mode {
        case menu, create, join
    }

    var body: some View {
        NavigationStack {
            Group {
                if let household = householdManager.currentHousehold {
                    householdDetailView(household)
                } else {
                    switch mode {
                    case .menu:   menuView
                    case .create: createView
                    case .join:   joinView
                    }
                }
            }
            .navigationTitle("ファミリー共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInView()
            }
        }
    }

    // MARK: - No Household: Menu

    private var menuView: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.accentColor)
                        .padding(.top, 16)
                    Text("ファミリー共有")
                        .font(.title2.bold())
                    Text("家族と在庫リストを共有しましょう。\n世帯を作成するか、招待コードで参加してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if authManager.isAnonymous {
                Section {
                    VStack(spacing: 8) {
                        Text("ファミリー共有にはアカウントが必要です")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Button("Sign in with Apple でログイン") {
                            showSignIn = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    Button {
                        mode = .create
                    } label: {
                        Label("世帯を作成する", systemImage: "plus.circle.fill")
                    }

                    Button {
                        mode = .join
                    } label: {
                        Label("招待コードで参加する", systemImage: "person.badge.plus")
                    }
                }
            }
        }
    }

    // MARK: - No Household: Create

    private var createView: some View {
        Form {
            Section("世帯名") {
                TextField("例：田中家", text: $householdName)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task { await createHousehold() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("世帯を作成する")
                        }
                        Spacer()
                    }
                }
                .disabled(householdName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
        }
        .navigationTitle("世帯を作成")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("戻る") { mode = .menu }
            }
        }
        .alert("エラー", isPresented: .constant(householdManager.errorMessage != nil)) {
            Button("OK") { householdManager.errorMessage = nil }
        } message: {
            Text(householdManager.errorMessage ?? "")
        }
    }

    // MARK: - No Household: Join

    private var joinView: some View {
        Form {
            Section("招待コード") {
                TextField("コードを入力してください", text: $inviteCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Section {
                Button {
                    Task { await joinHousehold() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("参加する")
                        }
                        Spacer()
                    }
                }
                .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }

            Section {
                Text("招待コードは世帯のオーナーから受け取ってください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("世帯に参加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("戻る") { mode = .menu }
            }
        }
        .alert("エラー", isPresented: .constant(householdManager.errorMessage != nil)) {
            Button("OK") { householdManager.errorMessage = nil }
        } message: {
            Text(householdManager.errorMessage ?? "")
        }
    }

    // MARK: - In a Household: Detail

    @ViewBuilder
    private func householdDetailView(_ household: Household) -> some View {
        let isOwner = household.ownerUid == authManager.currentUserId

        Form {
            Section("世帯情報") {
                HStack {
                    Text("世帯名")
                    Spacer()
                    Text(household.name)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("メンバー数")
                    Spacer()
                    Text("\(household.memberUids.count)人")
                        .foregroundStyle(.secondary)
                }
            }

            Section("招待コード") {
                HStack {
                    Text(household.inviteCode)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = household.inviteCode
                        showCopiedFeedback = true
                    } label: {
                        Label(
                            showCopiedFeedback ? "コピー済み" : "コピー",
                            systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(showCopiedFeedback ? .green : .accentColor)
                    }
                    .buttonStyle(.borderless)
                    .onChange(of: showCopiedFeedback) { _, newValue in
                        if newValue {
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                showCopiedFeedback = false
                            }
                        }
                    }
                }
                Text("このコードを家族に共有してください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if isOwner {
                    Text("あなたはこの世帯のオーナーです")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    showLeaveConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text(isOwner ? "世帯を解散する" : "世帯から退出する")
                        Spacer()
                    }
                }
                .disabled(isLoading)
            }
        }
        .confirmationDialog(
            isOwner ? "世帯を解散しますか？" : "世帯から退出しますか？",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button(isOwner ? "解散する" : "退出する", role: .destructive) {
                Task { await leaveHousehold() }
            }
        } message: {
            Text(isOwner
                ? "世帯を解散すると、全メンバーが共有データにアクセスできなくなります。"
                : "退出すると、この世帯の在庫データにアクセスできなくなります。"
            )
        }
        .alert("エラー", isPresented: .constant(householdManager.errorMessage != nil)) {
            Button("OK") { householdManager.errorMessage = nil }
        } message: {
            Text(householdManager.errorMessage ?? "")
        }
    }

    // MARK: - Actions

    private func createHousehold() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await householdManager.createHousehold(
                name: householdName.trimmingCharacters(in: .whitespaces)
            )
            firestoreManager.restartListening()
        } catch {
            // errorMessage is set on householdManager by the service itself
        }
    }

    private func joinHousehold() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await householdManager.joinHousehold(
                inviteCode: inviteCode.trimmingCharacters(in: .whitespaces)
            )
            firestoreManager.restartListening()
        } catch {
            // errorMessage is set on householdManager by the service itself
        }
    }

    private func leaveHousehold() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await householdManager.leaveHousehold()
            firestoreManager.restartListening()
        } catch {
            // errorMessage is set on householdManager by the service itself
        }
    }
}
