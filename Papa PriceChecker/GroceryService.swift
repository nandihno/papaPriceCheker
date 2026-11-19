import Foundation

struct GroceryRetailer: Decodable, Identifiable, Equatable {
  let chain: String
  let displayName: String

  static let woolworths = GroceryRetailer(chain: "woolworths", displayName: "Woolworths")

  var id: String { chain }

  enum CodingKeys: String, CodingKey {
    case chain
    case displayName = "display_name"
  }

  static func displayName(for chain: String, in retailers: [Self]) -> String {
    retailers.first { $0.chain == chain }?.displayName
      ?? (chain == "aldi" ? "ALDI" : chain.replacingOccurrences(of: "-", with: " ").capitalized)
  }
}

struct GroceryProduct: Decodable, Identifiable, Hashable {
  let productID: UUID
  let chain: String
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
    case chain, name, brand, price, promotion, url, region
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

private struct CompletedScrapeRun: Decodable {
  let finishedAt: Date

  enum CodingKeys: String, CodingKey {
    case finishedAt = "finished_at"
  }
}

/// Public configuration. The publishable key is not an access-control secret.
enum GroceryConfiguration {
  static let url = settings.url
  static let publishableKey = settings.publishableKey

  private static let settings: (url: URL, publishableKey: String) = {
    #if DEBUG
      let environment = ProcessInfo.processInfo.environment
      let address = environment["PAPA_PRICECHECKER_SUPABASE_URL"]
      let publishableKey = environment["PAPA_PRICECHECKER_SUPABASE_PUBLISHABLE_KEY"]
      if address != nil || publishableKey != nil {
        guard let address, let url = URL(string: address), url.scheme == "https", url.host != nil,
          let key = publishableKey, key.hasPrefix("sb_publishable_")
        else { preconditionFailure("Set both staging Supabase environment variables.") }
        return (url, key)
      }
    #endif
    return (
      URL(string: "https://wntllezsoavodlrpqcue.supabase.co")!,
      "sb_publishable_GOqwNwuuM-X77UWa7MdXTg_4pIiU_7l"
    )
  }()
}

/// Public, read-only PostgREST access. Database grants and RLS enforce access.
struct GroceryService {
  private let endpoint = GroceryConfiguration.url.appendingPathComponent("rest/v1")
  static let pageSize = 50
  private static let productSelectColumns =
    "product_id,chain,name,brand,package_size,price,was_price,is_on_special,promotion,cup_string,is_available,scraped_at,last_seen_at,image_url,url,region"

  func retailers() async throws -> [GroceryRetailer] {
    try await get(
      "retailers",
      query: [
        URLQueryItem(name: "select", value: "chain,display_name"),
        URLQueryItem(name: "enabled", value: "eq.true"),
        URLQueryItem(name: "order", value: "display_name.asc,chain.asc"),
      ])
  }

  func latestCatalogSnapshot(chain: String) async throws -> Date? {
    // The ingest function writes the product count after processing prices.
    // The scrape's finish time dates the snapshot even if that run is replayed.
    let runs: [CompletedScrapeRun] = try await get(
      "scrape_runs",
      query: [
        URLQueryItem(name: "select", value: "finished_at"),
        URLQueryItem(name: "chain", value: "eq.\(chain)"),
        URLQueryItem(name: "status", value: "eq.SUCCEEDED"),
        URLQueryItem(name: "products_upserted", value: "gt.0"),
        URLQueryItem(name: "finished_at", value: "not.is.null"),
        URLQueryItem(name: "order", value: "finished_at.desc"),
        URLQueryItem(name: "limit", value: "1"),
      ])
    return runs.first?.finishedAt
  }

  func products(chain: String, search: String, offset: Int) async throws -> [GroceryProduct] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    let chainFilter = URLQueryItem(name: "chain", value: "eq.\(chain)")
    if !term.isEmpty {
      let query = [
        URLQueryItem(name: "select", value: Self.productSelectColumns),
        URLQueryItem(name: "search_text", value: term),
        URLQueryItem(name: "page_size", value: "\(Self.pageSize)"),
        URLQueryItem(name: "page_offset", value: "\(offset)"),
      ]
      do {
        return try await get(
          "rpc/search_products_by_chain",
          query: query + [URLQueryItem(name: "retailer_chain", value: chain)])
      } catch GroceryError.server(404) where chain == GroceryRetailer.woolworths.chain {
        // Support the existing Woolworths-only backend during rollout.
        return try await get("rpc/search_products", query: query + [chainFilter])
      }
    }
    return try await get(
      "v_latest_prices",
      query: [
        URLQueryItem(name: "select", value: Self.productSelectColumns),
        chainFilter,
        URLQueryItem(name: "order", value: "name.asc,product_id.asc"),
        URLQueryItem(name: "limit", value: "\(Self.pageSize)"),
        URLQueryItem(name: "offset", value: "\(offset)"),
      ])
  }

  func products(ids: [UUID], chain: String? = nil) async throws -> [GroceryProduct] {
    var seen = Set<UUID>()
    let uniqueIDs = ids.filter { seen.insert($0).inserted }
    guard !uniqueIDs.isEmpty else { return [] }

    var collected: [GroceryProduct] = []
    let chunkSize = 100
    let chainFilter = chain.map { [URLQueryItem(name: "chain", value: "eq.\($0)")] } ?? []
    for start in stride(from: 0, to: uniqueIDs.count, by: chunkSize) {
      let end = min(start + chunkSize, uniqueIDs.count)
      let idList = uniqueIDs[start..<end].map(\.uuidString).joined(separator: ",")
      let page: [GroceryProduct] = try await get(
        "v_latest_prices",
        query: [
          URLQueryItem(name: "select", value: Self.productSelectColumns),
          URLQueryItem(name: "product_id", value: "in.(\(idList))"),
          URLQueryItem(name: "order", value: "name.asc,product_id.asc"),
        ] + chainFilter)
      collected.append(contentsOf: page)
    }
    return collected.sorted {
      if $0.name != $1.name {
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      return $0.id.uuidString < $1.id.uuidString
    }
  }

  func priceChangeSummaries(chain: String) async throws -> [UUID: PriceChangeSummary] {
    var grouped: [UUID: [Double?]] = [:]
    var offset = 0
    let pageSize = 1000
    while true {
      let page: [CompactHistoryRow] = try await get(
        "price_history",
        query: [
          URLQueryItem(name: "select", value: "product_id,price"),
          URLQueryItem(name: "chain", value: "eq.\(chain)"),
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
    // PostgREST decodes an unescaped plus in the query string as a space.
    components.percentEncodedQuery = components.percentEncodedQuery?
      .replacingOccurrences(of: "+", with: "%2B")
    var request = URLRequest(url: components.url!)
    request.setValue(GroceryConfiguration.publishableKey, forHTTPHeaderField: "apikey")
    request.setValue(
      "Bearer \(GroceryConfiguration.publishableKey)", forHTTPHeaderField: "Authorization")
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
