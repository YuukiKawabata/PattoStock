import Foundation

struct ProductInfo {
    let name: String
    let category: String?
    let barcode: String
}

actor ProductLookupService {
    func lookup(barcode: String) async -> ProductInfo? {
        // Open Food Facts API (free, no API key required)
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let status = json?["status"] as? Int, status == 1,
                  let product = json?["product"] as? [String: Any] else { return nil }

            let name = product["product_name_ja"] as? String
                ?? product["product_name"] as? String
                ?? product["generic_name"] as? String

            guard let productName = name, !productName.isEmpty else { return nil }

            let category = (product["categories_tags"] as? [String])?.first?
                .replacingOccurrences(of: "en:", with: "")
                .replacingOccurrences(of: "ja:", with: "")

            return ProductInfo(name: productName, category: mapCategory(category), barcode: barcode)
        } catch {
            return nil
        }
    }

    private func mapCategory(_ raw: String?) -> String? {
        guard let raw = raw?.lowercased() else { return nil }
        if raw.contains("beverage") || raw.contains("drink") { return "飲料" }
        if raw.contains("dairy") || raw.contains("milk") { return "食品" }
        if raw.contains("snack") || raw.contains("food") { return "食品" }
        if raw.contains("cleaning") || raw.contains("detergent") { return "洗剤" }
        return "その他"
    }
}
