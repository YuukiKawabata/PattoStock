import SwiftUI
import VisionKit

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onScan: (String, ProductInfo?) -> Void

    @State private var isScanning = false
    @State private var scannedCode: String?
    @State private var productInfo: ProductInfo?
    @State private var isLookingUp = false
    @State private var lookupFailed = false

    var body: some View {
        NavigationStack {
            VStack {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(onBarcode: handleBarcode)
                        .ignoresSafeArea()
                        .overlay(alignment: .bottom) {
                            resultOverlay
                        }
                } else {
                    manualEntryView
                }
            }
            .navigationTitle("バーコードスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var resultOverlay: some View {
        if let code = scannedCode {
            VStack(spacing: 12) {
                if isLookingUp {
                    ProgressView("商品情報を検索中...")
                } else if let info = productInfo {
                    VStack(spacing: 4) {
                        Text(info.name).font(.headline)
                        if let cat = info.category {
                            Text(cat).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("この商品を使う") {
                        onScan(code, productInfo)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("バーコード: \(code)")
                        .font(.subheadline)
                    if lookupFailed {
                        Text("商品情報が見つかりませんでした")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("このバーコードを使う") {
                        onScan(code, nil)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding()
        }
    }

    private var manualEntryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("カメラが利用できません")
                .font(.headline)
            Text("このデバイスではバーコードスキャンを利用できません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func handleBarcode(_ code: String) {
        guard scannedCode == nil else { return }
        scannedCode = code
        isLookingUp = true

        Task {
            let service = ProductLookupService()
            let info = await service.lookup(barcode: code)
            productInfo = info
            lookupFailed = info == nil
            isLookingUp = false
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcode: (String) -> Void
        private nonisolated(unsafe) var hasScanned = false

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        nonisolated func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue {
                    hasScanned = true
                    Task { @MainActor in
                        self.onBarcode(payload)
                    }
                    return
                }
            }
        }
    }
}
