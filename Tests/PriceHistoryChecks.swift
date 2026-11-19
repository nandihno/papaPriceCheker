import Foundation

@main
struct PriceHistoryChecks {
  static func main() throws {
    let json = """
      [
        {"id":"00000000-0000-0000-0000-000000000001","price":10,"was_price":12,
         "savings_amount":2,"discount_pct":16.67,"is_on_special":true,"is_half_price":false,
         "is_multibuy":false,"product_limit":36,"cup_price":1.5,"cup_measure":"100G",
         "cup_string":"$1.50 / 100G","is_available":true,"region":"syd2",
         "scraped_at":"2026-11-01T00:00:00Z"},
        {"id":"00000000-0000-0000-0000-000000000002","price":8,"was_price":10,
         "is_on_special":true,"is_half_price":false,"is_multibuy":false,
         "scraped_at":"2026-11-02T00:00:00Z"},
        {"id":"00000000-0000-0000-0000-000000000003","price":null,
         "is_on_special":false,"is_half_price":false,"is_multibuy":false,"is_available":false,
         "scraped_at":"2026-11-03T00:00:00Z"},
        {"id":"00000000-0000-0000-0000-000000000004","price":9,
         "is_on_special":false,"is_half_price":false,"is_multibuy":false,
         "scraped_at":"2026-11-04T00:00:00Z"}
      ]
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let records = try decoder.decode([PriceRecord].self, from: Data(json.utf8))
    let summary = PriceHistoryInsights(records: records)
    precondition(summary.lowest == 8 && summary.highest == 10 && summary.pricedCount == 3)
    precondition(summary.entries[0].priceChange == nil)
    precondition(summary.entries[1].priceChange == -2)
    precondition(summary.entries[2].priceChange == nil)
    precondition(summary.entries[3].priceChange == nil, "Do not compare across missing prices")
    precondition(records[0].wasPrice == 12 && records[0].savingsAmount == 2)
    precondition(records[0].discountPercent == 16.67 && records[0].unitPriceText == "$1.50 / 100G")
    precondition(records[0].productLimit == 36 && records[0].isAvailable == true)
    precondition(records[2].isAvailable == false && records[2].price == nil)
    let empty = PriceHistoryInsights(records: [])
    precondition(empty.lowest == nil && empty.highest == nil && empty.pricedCount == 0)

    let rise = PriceChangeSummary(prices: [6.0, 6.7])
    precondition(
      rise.direction == .increased && rise.previousPrice == 6.0 && rise.latestPrice == 6.7)
    precondition(abs((rise.delta ?? 0) - 0.7) < 0.0001)

    let drop = PriceChangeSummary(prices: [10.0, 8.0])
    precondition(
      drop.direction == .decreased && drop.previousPrice == 10.0 && drop.latestPrice == 8.0)
    precondition(abs((drop.delta ?? 0) + 2.0) < 0.0001)

    let same = PriceChangeSummary(prices: [5.0, 5.0])
    precondition(same.direction == .unchanged && same.delta == 0)

    let single = PriceChangeSummary(prices: [4.5])
    precondition(single.direction == .singleSnapshot && single.delta == nil)

    let gap = PriceChangeSummary(prices: [10.0, nil, 9.0])
    precondition(gap.direction == .singleSnapshot && gap.delta == nil)

    let emptySummary = PriceChangeSummary(prices: [])
    precondition(emptySummary.direction == .singleSnapshot && emptySummary.delta == nil)

    func product(price: String = "6.70", lastSeen: String) throws -> GroceryProduct {
      let json = """
        {"product_id":"00000000-0000-0000-0000-000000000005","chain":"aldi","name":"Milk","price":\(price),
         "is_on_special":false,"scraped_at":"2026-11-02T00:00:00Z","last_seen_at":\(lastSeen)}
        """
      return try decoder.decode(GroceryProduct.self, from: Data(json.utf8))
    }

    let checked = try product(lastSeen: #""2026-11-03T00:00:00Z""#)
    let retailers = try decoder.decode(
      [GroceryRetailer].self,
      from: Data(#"[{"chain":"aldi","display_name":"ALDI"}]"#.utf8)
    )
    precondition(checked.chain == retailers.first?.chain)
    precondition(GroceryRetailer.displayName(for: checked.chain, in: retailers) == "ALDI")
    precondition(checked.unchangedPriceCheck?.date == checked.lastSeenAt)
    precondition(checked.unchangedPriceCheck?.price == 6.70)
    precondition(checked.latestPriceComparison(recorded: rise)?.direction == .unchanged)
    precondition(checked.latestPriceComparison(recorded: nil)?.direction == .unchanged)

    let sameDay = try product(lastSeen: #""2026-11-02T00:00:00Z""#)
    let noCheck = try product(lastSeen: "null")
    let olderCheck = try product(lastSeen: #""2026-11-01T00:00:00Z""#)
    for candidate in [sameDay, noCheck, olderCheck] {
      precondition(candidate.unchangedPriceCheck == nil)
      precondition(candidate.latestPriceComparison(recorded: rise)?.direction == .increased)
    }

    let unknownPrice = try product(price: "null", lastSeen: #""2026-11-03T00:00:00Z""#)
    precondition(unknownPrice.unchangedPriceCheck == nil)
    precondition(unknownPrice.latestPriceComparison(recorded: gap)?.delta == nil)

    print("Price-history decoding and insight checks passed.")
  }
}
