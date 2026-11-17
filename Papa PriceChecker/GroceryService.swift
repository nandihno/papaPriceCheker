import Foundation

struct GroceryProduct: Decodable, Identifiable, Hashable {
  let productID: UUID
  let name: String
  let brand: String?
  let packageSize: String?
  let price: Double?
  let wasPrice: Double?
  let isOnSpecial: Bool
  let promotion: String?
  let cupString: String?
  let isAvailable: Bool?
  let scrapedAt: Date
  let lastSeenAt: Date?
  let imageURL: URL?
  let url: URL?
  let region: String?

  var id: UUID { productID }
  enum CodingKeys: String, CodingKey {
    case productID = "product_id"
    case name, brand, price, promotion, url, region
    case packageSize = "package_size"
    case wasPrice = "was_price"
    case isOnSpecial = "is_on_special"
    case cupString = "cup_string"
    case isAvailable = "is_available"
    case scrapedAt = "scraped_at"
    case lastSeenAt = "last_seen_at"
    case imageURL = "image_url"
  }
}

struct PriceRecord: Decodable, Identifiable {
  let id: UUID
  let price: Double?
  let wasPrice: Double?
  let savingsAmount: Double?
  let discountPercent: Double?
  let isOnSpecial: Bool
  let isHalfPrice: Bool
  let isMultibuy: Bool
  let promotion: String?
  let productLimit: Int?
  let unitPrice: Double?
  let unitMeasure: String?
  let unitPriceText: String?
  let isAvailable: Bool?
  let region: String?
  let scrapedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, price, promotion, region
    case wasPrice = "was_price"
    case savingsAmount = "savings_amount"
    case discountPercent = "discount_pct"
    case isOnSpecial = "is_on_special"
    case isHalfPrice = "is_half_price"
    case isMultibuy = "is_multibuy"
    case productLimit = "product_limit"
    case unitPrice = "cup_price"
    case unitMeasure = "cup_measure"
    case unitPriceText = "cup_string"
    case isAvailable = "is_available"
    case scrapedAt = "scraped_at"
  }
}

enum GroceryError: LocalizedError {
  case badResponse
  case server(Int)
  var errorDescription: String? {
    switch self {
    case .badResponse: "The price service returned an unexpected response."
    case .server(let status): "The price service is unavailable (HTTP \(status))."
    }
  }
}

private struct CompactHistoryRow: Decodable {
  let productID: UUID
  let price: Double?

  enum CodingKeys: String, CodingKey {
    case productID = "product_id"
    case price
  }
}

/// Public, read-only PostgREST access. Database grants and RLS enforce access.
struct GroceryService {
  private let endpoint = URL(string: "https://wntllezsoavodlrpqcue.supabase.co/rest/v1")!
  private let publicKey = "sb_publishable_GOqwNwuuM-X77UWa7MdXTg_4pIiU_7l"
  static let pageSize = 50
  private static let productSelectColumns =
    "product_id,name,brand,package_size,price,was_price,is_on_special,promotion,cup_string,is_available,scraped_at,last_seen_at,image_url,url,region"

  func products(search: String, offset: Int) async throws -> [GroceryProduct] {
    var query = [
      URLQueryItem(name: "select", value: Self.productSelectColumns),
      URLQueryItem(name: "order", value: "name.asc,product_id.asc"),
      URLQueryItem(name: "limit", value: "\(Self.pageSize)"),
      URLQueryItem(name: "offset", value: "\(offset)"),
    ]
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    if !term.isEmpty {
      // PostgREST treats * as an ilike wildcard. Escape user wildcards.
      let escaped = term.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "%", with: "\\%")
        .replacingOccurrences(of: "_", with: "\\_")
        .replacingOccurrences(of: "*", with: "\\*")
      query.append(URLQueryItem(name: "name", value: "ilike.%\(escaped)%"))
    }
    return try await get("v_latest_prices", query: query)
  }

  func products(ids: [UUID]) async throws -> [GroceryProduct] {
    var seen = Set<UUID>()
    let uniqueIDs = ids.filter { seen.insert($0).inserted }
    guard !uniqueIDs.isEmpty else { return [] }

    var collected: [GroceryProduct] = []
    let chunkSize = 100
    for start in stride(from: 0, to: uniqueIDs.count, by: chunkSize) {
      let end = min(start + chunkSize, uniqueIDs.count)
      let idList = uniqueIDs[start..<end].map(\.uuidString).joined(separator: ",")
      let page: [GroceryProduct] = try await get(
        "v_latest_prices",
        query: [
          URLQueryItem(name: "select", value: Self.productSelectColumns),
          URLQueryItem(name: "product_id", value: "in.(\(idList))"),
          URLQueryItem(name: "order", value: "name.asc,product_id.asc"),
        ])
      collected.append(contentsOf: page)
    }
    return collected.sorted {
      if $0.name != $1.name { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      return $0.id.uuidString < $1.id.uuidString
    }
  }

  func priceChangeSummaries() async throws -> [UUID: PriceChangeSummary] {
    var grouped: [UUID: [Double?]] = [:]
    var offset = 0
    let pageSize = 1000
    while true {
      let page: [CompactHistoryRow] = try await get(
        "price_history",
        query: [
          URLQueryItem(name: "select", value: "product_id,price"),
          URLQueryItem(name: "order", value: "scraped_at.asc,id.asc"),
          URLQueryItem(name: "limit", value: "\(pageSize)"),
          URLQueryItem(name: "offset", value: "\(offset)"),
        ])
      for row in page {
        grouped[row.productID, default: []].append(row.price)
      }
      offset += page.count
      if page.count < pageSize {
        return grouped.mapValues { PriceChangeSummary(prices: $0) }
      }
    }
  }

  func history(productID: UUID) async throws -> [PriceRecord] {
    var all: [PriceRecord] = []
    let pageSize = 500
    while true {
      let page: [PriceRecord] = try await get(
        "price_history",
        query: [
          URLQueryItem(
            name: "select",
            value:
              "id,price,was_price,savings_amount,discount_pct,is_on_special,is_half_price,is_multibuy,promotion,product_limit,cup_price,cup_measure,cup_string,is_available,region,scraped_at"
          ),
          URLQueryItem(name: "product_id", value: "eq.\(productID.uuidString)"),
          URLQueryItem(name: "order", value: "scraped_at.asc,id.asc"),
          URLQueryItem(name: "limit", value: "\(pageSize)"),
          URLQueryItem(name: "offset", value: "\(all.count)"),
        ])
      all.append(contentsOf: page)
      if page.count < pageSize { return all }
    }
  }

  private func get<T: Decodable>(_ table: String, query: [URLQueryItem]) async throws -> T {
    var components = URLComponents(
      url: endpoint.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
    components.queryItems = query
    var request = URLRequest(url: components.url!)
    request.setValue(publicKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(publicKey)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw GroceryError.badResponse }
    guard (200..<300).contains(response.statusCode) else {
      throw GroceryError.server(response.statusCode)
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let fractional = ISO8601DateFormatter()
      fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(), debugDescription: "Invalid timestamp")
    }
    return try decoder.decode(T.self, from: data)
  }
}
