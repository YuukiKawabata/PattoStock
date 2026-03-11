import SwiftUI

struct SettingsView: View {
    @Environment(FirestoreManager.self) private var manager
    @Environment(HouseholdManager.self) private var householdManager

    @State private var notificationManager = NotificationManager.shared
    @State private var authManager = AuthManager.shared
    @State private var showSignIn = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showFamilySharing = false

    private let weekdays = [
        (1, "日曜日"), (2, "月曜日"), (3, "火曜日"), (4, "水曜日"),
        (5, "木曜日"), (6, "金曜日"), (7, "土曜日")
    ]

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                familySharingSection
                accountSection
                aboutSection
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showSignIn) {
                SignInView()
            }
            .sheet(isPresented: $showFamilySharing) {
                FamilySharingView()
            }
        }
    }

    private var notificationSection: some View {
        Section("通知") {
            if notificationManager.isAuthorized {
                Toggle("週次買い物リマインダー", isOn: $notificationManager.weeklyReminderEnabled)

                if notificationManager.weeklyReminderEnabled {
                    Picker("リマインダー曜日", selection: Binding(
                        get: { notificationManager.weeklyReminderDay },
                        set: { notificationManager.updateReminderDay($0) }
                    )) {
                        ForEach(weekdays, id: \.0) { day in
                            Text(day.1).tag(day.0)
                        }
                    }
                }
            } else {
                Button("通知を有効にする") {
                    Task {
                        _ = await notificationManager.requestAuthorization()
                    }
                }
            }
        }
    }

    private var familySharingSection: some View {
        Section("ファミリー共有") {
            if let household = householdManager.currentHousehold {
                HStack {
                    Image(systemName: "house.fill")
                        .foregroundStyle(.accentColor)
                    Text(household.name)
                }
                Button {
                    showFamilySharing = true
                } label: {
                    HStack {
                        Text("世帯を管理")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundStyle(.primary)
            } else {
                Button {
                    showFamilySharing = true
                } label: {
                    Label("ファミリー共有を設定する", systemImage: "person.2.fill")
                }
            }
        }
    }

    private var accountSection: some View {
        Section("アカウント") {
            if authManager.isSignedIn && !authManager.isAnonymous {
                if let email = authManager.userEmail {
                    HStack {
                        Text("メール")
                        Spacer()
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("サインアウト") {
                    try? authManager.signOut()
                }
                Button("アカウント削除", role: .destructive) {
                    showDeleteAccountConfirmation = true
                }
                .confirmationDialog("アカウントを削除しますか？", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
                    Button("削除", role: .destructive) {
                        Task { try? await authManager.deleteAccount() }
                    }
                } message: {
                    Text("この操作は取り消せません。すべてのデータが失われます。")
                }
            } else {
                Button("Sign in with Apple でログイン") {
                    showSignIn = true
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("このアプリについて") {
            HStack {
                Text("バージョン")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
        }
    }
}
