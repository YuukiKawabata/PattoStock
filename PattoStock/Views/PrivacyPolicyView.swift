import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("最終更新日：2026年3月11日")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    policySection(
                        title: "はじめに",
                        content: "Patto（以下「本アプリ」）は、ご家庭の在庫管理をサポートするアプリです。本プライバシーポリシーでは、本アプリが収集する情報と、その利用方法についてご説明します。"
                    )

                    policySection(
                        title: "収集する情報",
                        content: """
                        本アプリは以下の情報を収集します。

                        ■ アカウント情報
                        • 匿名認証ID（Firebaseにより自動生成）
                        • Apple IDのメールアドレス（Sign in with Apple使用時のみ）

                        ■ 在庫・利用データ
                        • 商品名、数量、カテゴリ、閾値、バーコード番号
                        • 消費履歴（日時・数量）
                        • 世帯情報（ファミリー共有使用時）

                        ■ アプリ設定
                        • 通知設定（曜日・時刻など）
                        • オンボーディング完了状態
                        """
                    )

                    policySection(
                        title: "情報の利用目的",
                        content: """
                        収集した情報は以下の目的で利用します。

                        • 在庫管理機能の提供
                        • 複数端末間のデータ同期
                        • ファミリー共有機能
                        • 在庫切れ・残量低下の通知
                        • 消費傾向の分析と補充予測
                        """
                    )
                }

                Group {
                    policySection(
                        title: "第三者サービスへの情報提供",
                        content: """
                        本アプリは以下の第三者サービスを利用します。

                        ■ Firebase（Google LLC）
                        ユーザー認証およびデータの保存に使用します。
                        データはGoogleのサーバーに保存されます。
                        プライバシーポリシー：https://policies.google.com/privacy

                        ■ Open Food Facts
                        バーコードスキャン時に商品情報を取得するために使用します。
                        スキャンしたバーコード番号のみが送信されます。個人情報は含まれません。
                        プライバシーポリシー：https://world.openfoodfacts.org/privacy
                        """
                    )

                    policySection(
                        title: "データの保管と削除",
                        content: """
                        • データはFirebaseのサーバー（米国・EU）に保管されます
                        • アカウントを削除すると、すべての在庫データ・消費履歴が削除されます
                        • 設定画面の「アカウント削除」からいつでも削除できます
                        • 匿名ユーザーがアプリを削除した場合、データへのアクセスは失われます
                        """
                    )

                    policySection(
                        title: "プッシュ通知",
                        content: "本アプリは、在庫切れの警告や週次リマインダーのためにプッシュ通知を送信することがあります。通知はデバイスの設定からいつでもオフにできます。"
                    )

                    policySection(
                        title: "お子様のプライバシー",
                        content: "本アプリは13歳未満のお子様を対象としておらず、意図的に13歳未満の方から個人情報を収集することはありません。"
                    )

                    policySection(
                        title: "本ポリシーの変更",
                        content: "本プライバシーポリシーは予告なく変更される場合があります。重要な変更がある場合はアプリ内でお知らせします。"
                    )

                    policySection(
                        title: "お問い合わせ",
                        content: "プライバシーに関するご質問は、アプリストアのサポートページからお問い合わせください。"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
