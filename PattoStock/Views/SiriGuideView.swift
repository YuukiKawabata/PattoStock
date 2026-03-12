import SwiftUI

struct SiriGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // イントロ
                VStack(alignment: .leading, spacing: 8) {
                    Text("Siriに話しかけるだけで、Pattoの在庫を操作・確認できます。")
                        .font(.body)

                    Text("「Hey Siri」と呼びかけるか、サイドボタンを長押ししてSiriを起動してください。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // 在庫操作セクション
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("在庫操作")

                    commandSection(
                        icon: "minus.circle.fill",
                        title: "在庫を減らす",
                        description: "登録済みアイテムの在庫を1つ減らします。",
                        phrases: ["Pattoで○○を減らして", "Pattoで○○を使った"]
                    )

                    commandSection(
                        icon: "plus.circle.fill",
                        title: "在庫を補充",
                        description: "アイテムの在庫を1つ補充します。",
                        phrases: ["Pattoで○○を補充", "Pattoに○○を追加"]
                    )

                    commandSection(
                        icon: "arrow.up.circle.fill",
                        title: "まとめて補充",
                        description: "アイテムの在庫を最大数まで一気に補充します。",
                        phrases: ["Pattoで○○をまとめて補充"]
                    )

                    commandSection(
                        icon: "plus.square.fill",
                        title: "新規アイテム追加",
                        description: "新しいアイテムをPattoに登録します。",
                        phrases: ["Pattoに新しいアイテムを登録して"]
                    )
                }

                // 確認・予測セクション
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("確認・予測")

                    commandSection(
                        icon: "cart.fill",
                        title: "買うものを確認",
                        description: "在庫が少なくなっているアイテムを一覧表示します。",
                        phrases: ["Pattoで買うものある？", "Pattoの在庫を確認"]
                    )

                    commandSection(
                        icon: "info.circle.fill",
                        title: "アイテムの状態",
                        description: "特定のアイテムの現在の在庫数や状態を確認します。",
                        phrases: ["Pattoで○○の状態を教えて"]
                    )

                    commandSection(
                        icon: "folder.fill",
                        title: "カテゴリ別在庫",
                        description: "カテゴリごとの在庫状況を確認します。",
                        phrases: ["Pattoの○○の在庫は？"]
                    )

                    commandSection(
                        icon: "clock.fill",
                        title: "在庫予測",
                        description: "消費ペースから、もうすぐ切れそうなアイテムを予測します。",
                        phrases: ["Pattoでもうすぐ切れるものは？"]
                    )
                }

                // フッターヒント
                Text("○○にはアプリに登録済みの商品名を入れてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Siri使い方ガイド")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3)
            .fontWeight(.bold)
    }

    private func commandSection(icon: String, title: String, description: String, phrases: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(phrases, id: \.self) { phrase in
                    Text("「\(phrase)」")
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        SiriGuideView()
    }
}
