import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(FirestoreManager.self) private var manager
    @State private var tracker = ConsumptionTracker()
    @State private var predictionEngine = PredictionEngine()
    @State private var selectedPeriod = 30

    private let periods = [7, 14, 30]

    var body: some View {
        NavigationStack {
            List {
                if tracker.events.isEmpty {
                    ContentUnavailableView(
                        "データなし",
                        systemImage: "chart.bar",
                        description: Text("在庫を使い始めるとトレンドが表示されます")
                    )
                } else {
                    predictionsSection
                    dailyChartSection
                    categoryChartSection
                }
            }
            .navigationTitle("トレンド")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(periods, id: \.self) { period in
                            Text("\(period)日").tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .task { await tracker.loadEvents(days: selectedPeriod) }
            .onChange(of: selectedPeriod) { _, newValue in
                Task { await tracker.loadEvents(days: newValue) }
            }
        }
    }

    private var predictionsSection: some View {
        Section("在庫切れ予測") {
            let predictions = predictionEngine.predictAll(items: manager.items, events: tracker.events)
                .filter { $0.isUrgent }

            if predictions.isEmpty {
                Text("直近で在庫切れになりそうなアイテムはありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(predictions, id: \.itemName) { prediction in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(prediction.itemName)
                        Spacer()
                        Text(prediction.predictionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var dailyChartSection: some View {
        Section("日別消費量") {
            Chart(tracker.dailyConsumption) { data in
                BarMark(
                    x: .value("日付", data.date, unit: .day),
                    y: .value("消費量", data.totalQuantity)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .padding(.vertical, 8)
        }
    }

    private var categoryChartSection: some View {
        Section("カテゴリ別消費量") {
            Chart(tracker.consumptionByCategory) { data in
                SectorMark(
                    angle: .value("消費量", data.totalQuantity),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("カテゴリ", data.category))
                .annotation(position: .overlay) {
                    Text("\(data.totalQuantity)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 200)
            .padding(.vertical, 8)
        }
    }
}
