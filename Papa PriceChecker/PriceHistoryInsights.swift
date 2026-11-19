import Foundation

nonisolated enum PriceDirection: String, Equatable, Sendable {
  case increased
  case decreased
  case unchanged
  case singleSnapshot
}

nonisolated struct PriceChangeSummary: Equatable, Sendable {
  let previousPrice: Double?
  let latestPrice: Double?
  init(previousPrice: Double?, latestPrice: Double?) {
    self.previousPrice = previousPrice
    self.latestPrice = latestPrice
  }

  init(prices: [Double?]) {
    self.latestPrice = prices.last ?? nil
    self.previousPrice = prices.count >= 2 ? prices[prices.count - 2] : nil
  }

  /// Change between the latest and preceding observations when both prices are known.
  var delta: Double? {
    guard let latestPrice, let previousPrice else { return nil }
    return latestPrice - previousPrice
  }

  var direction: PriceDirection {
    guard let delta else { return .singleSnapshot }
    if delta > 0.005 { return .increased }
    if delta < -0.005 { return .decreased }
    return .unchanged
  }
}

struct UnchangedPriceCheck {
  let date: Date
  let price: Double
}

extension GroceryProduct {
  var unchangedPriceCheck: UnchangedPriceCheck? {
    guard let price, let lastSeenAt, lastSeenAt > scrapedAt else { return nil }
    return UnchangedPriceCheck(date: lastSeenAt, price: price)
  }

  func latestPriceComparison(recorded: PriceChangeSummary?) -> PriceChangeSummary? {
    guard let check = unchangedPriceCheck else { return recorded }
    return PriceChangeSummary(previousPrice: check.price, latestPrice: check.price)
  }
}

struct HistoryEntry: Identifiable {
  let record: PriceRecord
  let previousPrice: Double?
  var id: UUID { record.id }

  /// Change since the immediately preceding recorded snapshot, not the retailer's was-price.
  var priceChange: Double? {
    guard let price = record.price, let previousPrice else { return nil }
    return price - previousPrice
  }
}

struct PriceHistoryInsights {
  let entries: [HistoryEntry]
  let lowest: Double?
  let highest: Double?
  let pricedCount: Int

  init(records: [PriceRecord]) {
    entries = records.enumerated().map { index, record in
      HistoryEntry(record: record, previousPrice: index > 0 ? records[index - 1].price : nil)
    }
    let prices = records.compactMap(\.price)
    lowest = prices.min()
    highest = prices.max()
    pricedCount = prices.count
  }
}
