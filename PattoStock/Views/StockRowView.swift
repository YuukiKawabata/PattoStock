import SwiftUI

struct StockRowView: View {
    @Environment(FirestoreManager.self) private var manager
    let item: InventoryItem
    var onTap: () -> Void = {}

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            Circle()
                .fill(item.statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    guard let id = item.id else { return }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    Task {
                        try? await manager.updateCount(itemId: id, delta: -1)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .disabled(item.currentCount <= 0)

                Text("\(item.currentCount)")
                    .font(.title3.monospacedDigit())
                    .frame(minWidth: 28)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: item.currentCount)

                Button {
                    guard let id = item.id else { return }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    Task {
                        try? await manager.updateCount(itemId: id, delta: 1)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDeleteConfirmation = true
            } label: {
                Label("削除", systemImage: "trash")
            }
            .tint(.red)
        }
        .confirmationDialog("「\(item.name)」を削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                guard let id = item.id else { return }
                Task { try? await manager.deleteItem(id: id) }
            }
        }
    }
}
