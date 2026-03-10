import WidgetKit
import SwiftUI

struct ShoppingListEntry: TimelineEntry {
    let date: Date
    let items: [ShoppingItem]

    struct ShoppingItem: Identifiable {
        let id: String
        let name: String
        let currentCount: Int
        let restockAmount: Int
    }
}

struct ShoppingListProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoppingListEntry {
        ShoppingListEntry(date: .now, items: [
            .init(id: "1", name: "牛乳", currentCount: 0, restockAmount: 2),
            .init(id: "2", name: "パン", currentCount: 1, restockAmount: 1),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingListEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingListEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> ShoppingListEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.yuuki.PattoStock"),
              let data = defaults.data(forKey: "shoppingList"),
              let decoded = try? JSONDecoder().decode([WidgetShoppingItem].self, from: data) else {
            return ShoppingListEntry(date: .now, items: [])
        }

        let items = decoded.map {
            ShoppingListEntry.ShoppingItem(
                id: $0.id,
                name: $0.name,
                currentCount: $0.currentCount,
                restockAmount: $0.restockAmount
            )
        }
        return ShoppingListEntry(date: .now, items: items)
    }
}

private struct WidgetShoppingItem: Codable {
    let id: String
    let name: String
    let currentCount: Int
    let restockAmount: Int
}

struct ShoppingListWidget: Widget {
    let kind = "ShoppingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShoppingListProvider()) { entry in
            ShoppingListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("買い物リスト")
        .description("補充が必要なアイテムを表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ShoppingListWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ShoppingListEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Color.accentColor)
                Text("買い物")
                    .font(.headline)
            }
            Spacer()
            if entry.items.isEmpty {
                Text("買い物なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(entry.items.count)")
                    .font(.system(size: 40, weight: .bold))
                Text("アイテム")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Color.accentColor)
                Text("買い物リスト")
                    .font(.headline)
                Spacer()
                Text("\(entry.items.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.items.isEmpty {
                Spacer()
                Text("買い足すものはありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items.prefix(4)) { item in
                    HStack {
                        Circle()
                            .fill(item.currentCount <= 0 ? .red : .yellow)
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text("x\(item.restockAmount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if entry.items.count > 4 {
                    Text("他 \(entry.items.count - 4) 件")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview(as: .systemSmall) {
    ShoppingListWidget()
} timeline: {
    ShoppingListEntry(date: .now, items: [
        .init(id: "1", name: "牛乳", currentCount: 0, restockAmount: 2),
        .init(id: "2", name: "パン", currentCount: 1, restockAmount: 1),
    ])
}
