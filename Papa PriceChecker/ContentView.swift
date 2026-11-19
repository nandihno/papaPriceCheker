import Charts
import SwiftUI
import UIKit

private enum Theme {
  static let brand = dynamicColor(
    light: UIColor(red: 0x12 / 255, green: 0x6B / 255, blue: 0x49 / 255, alpha: 1),
    dark: UIColor(red: 0x3E / 255, green: 0xE0 / 255, blue: 0x94 / 255, alpha: 1),
    highContrastLight: UIColor(red: 0x0A / 255, green: 0x4D / 255, blue: 0x34 / 255, alpha: 1),
    highContrastDark: UIColor(red: 0x6E / 255, green: 0xF0 / 255, blue: 0xB2 / 255, alpha: 1)
  )

  static let brandSurface = dynamicColor(
    light: UIColor(red: 0x12 / 255, green: 0x6B / 255, blue: 0x49 / 255, alpha: 0.10),
    dark: UIColor(red: 0x3E / 255, green: 0xE0 / 255, blue: 0x94 / 255, alpha: 0.15)
  )

  static let special = dynamicColor(
    light: UIColor(red: 0x9A / 255, green: 0x42 / 255, blue: 0x00 / 255, alpha: 1),
    dark: UIColor(red: 0xFB / 255, green: 0xBF / 255, blue: 0x24 / 255, alpha: 1),
    highContrastLight: UIColor(red: 0x7A / 255, green: 0x32 / 255, blue: 0x00 / 255, alpha: 1),
    highContrastDark: UIColor(red: 0xFD / 255, green: 0xD3 / 255, blue: 0x5C / 255, alpha: 1)
  )

  static let specialSurface = dynamicColor(
    light: UIColor(red: 0x9A / 255, green: 0x42 / 255, blue: 0x00 / 255, alpha: 0.10),
    dark: UIColor(red: 0xFB / 255, green: 0xBF / 255, blue: 0x24 / 255, alpha: 0.16)
  )

  static let priceRise = dynamicColor(
    light: UIColor(red: 0xB4 / 255, green: 0x23 / 255, blue: 0x18 / 255, alpha: 1),
    dark: UIColor(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255, alpha: 1),
    highContrastLight: UIColor(red: 0x8C / 255, green: 0x16 / 255, blue: 0x0E / 255, alpha: 1),
    highContrastDark: UIColor(red: 0xFF / 255, green: 0x94 / 255, blue: 0x94 / 255, alpha: 1)
  )

  static let priceRiseColumnSurface = dynamicColor(
    light: UIColor(red: 0xFC / 255, green: 0xE8 / 255, blue: 0xE8 / 255, alpha: 1),
    dark: UIColor(red: 0.52, green: 0.14, blue: 0.16, alpha: 0.30)
  )

  static let priceDropColumnSurface = dynamicColor(
    light: UIColor(red: 0xE8 / 255, green: 0xF7 / 255, blue: 0xEE / 255, alpha: 1),
    dark: UIColor(red: 0.08, green: 0.42, blue: 0.28, alpha: 0.30)
  )

  static let heroAccent = Color(red: 0.83, green: 0.95, blue: 0.47)

  static let heroGradient = LinearGradient(
    colors: [
      dynamicColor(
        light: UIColor(red: 0x0B / 255, green: 0x3B / 255, blue: 0x2B / 255, alpha: 1),
        dark: UIColor(red: 0x09 / 255, green: 0x29 / 255, blue: 0x1E / 255, alpha: 1)
      ),
      dynamicColor(
        light: UIColor(red: 0x16 / 255, green: 0x5B / 255, blue: 0x42 / 255, alpha: 1),
        dark: UIColor(red: 0x12 / 255, green: 0x45 / 255, blue: 0x32 / 255, alpha: 1)
      ),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  private static func dynamicColor(
    light: UIColor,
    dark: UIColor,
    highContrastLight: UIColor? = nil,
    highContrastDark: UIColor? = nil
  ) -> Color {
    Color(
      uiColor: UIColor { traits in
        let isDark = traits.userInterfaceStyle == .dark
        if traits.accessibilityContrast == .high {
          return isDark ? (highContrastDark ?? dark) : (highContrastLight ?? light)
        }
        return isDark ? dark : light
      }
    )
  }
}

private nonisolated struct DivisionLayout: Equatable, Sendable {
  let isVertical: Bool
  let width: CGFloat

  static let none = DivisionLayout(isVertical: false, width: 0)
}

private enum ProductFilter: String, CaseIterable, Identifiable {
  case all
  case decreased
  case increased
  case specials

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: "All"
    case .decreased: "Drops"
    case .increased: "Rises"
    case .specials: "Specials"
    }
  }

  var menuTitle: String {
    switch self {
    case .all: "All Products"
    case .decreased: "Price Drops"
    case .increased: "Price Rises"
    case .specials: "Specials Only"
    }
  }

  var systemImage: String {
    switch self {
    case .all: "basket"
    case .decreased: "arrow.down.right.circle.fill"
    case .increased: "arrow.up.right.circle.fill"
    case .specials: "tag.fill"
    }
  }
}

struct ContentView: View {
  private enum CatalogSnapshot: Equatable {
    case pending
    case dated(Date)
    case unavailable
  }

  private struct BrowseQuery: Equatable {
    let chain: String
    let search: String
  }

  @State private var showingFavourites = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var search = ""
  @State private var retailers: [GroceryRetailer] = [.woolworths]
  @State private var retailer = GroceryRetailer.woolworths
  @State private var loadID = UUID()
  @State private var loadedQuery: BrowseQuery?
  @State private var catalogSnapshot: CatalogSnapshot = .pending
  @State private var baseProducts: [GroceryProduct] = []
  @State private var changedProducts: [GroceryProduct] = []
  @State private var summaries: [UUID: PriceChangeSummary] = [:]
  @State private var selectedProduct: GroceryProduct?
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
  @State private var filter: ProductFilter = .all
  @State private var loading = false
  @State private var loadingMore = false
  @State private var hasMore = false
  @State private var error: String?
  @State private var pageError: String?

  private let service = GroceryService()

  private var browseQuery: BrowseQuery { BrowseQuery(chain: retailer.chain, search: search) }

  private var allKnownProducts: [GroceryProduct] {
    guard search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return baseProducts
    }
    var seen = Set(baseProducts.map(\.id))
    var combined = baseProducts
    for product in changedProducts where seen.insert(product.id).inserted {
      combined.append(product)
    }
    return combined
  }

  private var decreasedCount: Int {
    allKnownProducts.filter { summary(for: $0)?.direction == .decreased }.count
  }

  private var increasedCount: Int {
    allKnownProducts.filter { summary(for: $0)?.direction == .increased }.count
  }

  private var specialsCount: Int {
    allKnownProducts.filter(\.isOnSpecial).count
  }

  private var displayedProducts: [GroceryProduct] {
    let items: [GroceryProduct]
    switch filter {
    case .all:
      if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let changed = allKnownProducts
          .filter {
            let dir = summary(for: $0)?.direction
            return dir == .decreased || dir == .increased
          }
          .sorted {
            if $0.name != $1.name {
              return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.id.uuidString < $1.id.uuidString
          }
        let unchanged = allKnownProducts.filter {
          let dir = summary(for: $0)?.direction
          return dir != .decreased && dir != .increased
        }
        items = changed + unchanged
      } else {
        items = allKnownProducts
      }
    case .decreased:
      items = allKnownProducts.filter { summary(for: $0)?.direction == .decreased }
    case .increased:
      items = allKnownProducts.filter { summary(for: $0)?.direction == .increased }
    case .specials:
      items = allKnownProducts.filter(\.isOnSpecial)
    }
    return items
  }

  private var canLoadMoreInCurrentFilter: Bool {
    guard hasMore else { return false }
    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return filter == .all || filter == .specials
    }
    return true
  }

  private var alertColumns: [GridItem] {
    let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
    return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
  }

  private func summary(for product: GroceryProduct) -> PriceChangeSummary? {
    product.latestPriceComparison(recorded: summaries[product.id])
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
      sidebar
        .navigationSplitViewColumnWidth(min: 300, ideal: 370, max: 450)
    } detail: {
      detailPane
    }
    .navigationSplitViewStyle(.balanced)
    .sheet(isPresented: $showingFavourites) {
      FavouritesView(retailers: retailers) { product in
        if let destination = retailers.first(where: { $0.chain == product.chain }) {
          selectRetailer(destination)
        }
        selectedProduct = product
        preferredColumn = .detail
      }
    }
    .tint(Theme.brand)
    .task { await loadRetailers() }
    .task(id: browseQuery) {
      do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
      await load(refreshCatalogSnapshot: false)
    }
  }

  private var sidebar: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 8) {
          intro
          if retailers.count > 1 {
            Picker("Retailer", selection: retailerSelection) {
              ForEach(retailers) { retailer in
                Text(retailer.displayName).tag(retailer.chain)
              }
            }
            .pickerStyle(.menu)
          }
          catalogSnapshotStatus
        }
        if !loading, error == nil, search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          decreasedCount > 0 || increasedCount > 0
        {
          priceMovementBanner
        }
        VStack(alignment: .leading, spacing: 12) {
          listHeader
          if loading {
            ProgressView("Finding prices…")
              .frame(maxWidth: .infinity)
              .padding(.vertical, 48)
          } else if let error {
            ContentUnavailableView {
              Label("Couldn’t load prices", systemImage: "wifi.exclamationmark")
            } description: {
              Text(error)
            } actions: {
              Button("Try again") { Task { await load() } }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 12)
          } else if allKnownProducts.isEmpty {
            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              ContentUnavailableView("No products available", systemImage: "basket")
                .padding(.top, 12)
            } else {
              ContentUnavailableView.search(text: search)
                .padding(.top, 12)
            }
          } else if displayedProducts.isEmpty {
            ContentUnavailableView {
              Label(emptyFilterTitle, systemImage: filter.systemImage)
            } description: {
              Text(emptyFilterDescription)
            } actions: {
              HStack(spacing: 12) {
                Button("Show all products") {
                  withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                    filter = .all
                  }
                }
                .buttonStyle(.bordered)
                if canLoadMoreInCurrentFilter {
                  Button("Load more") { Task { await loadMore() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(loadingMore)
                }
              }
            }
            .padding(.top, 12)
          } else {
            LazyVStack(spacing: 10) {
              ForEach(displayedProducts) { product in
                let isSelected = selectedProduct?.id == product.id
                Button {
                  selectedProduct = product
                  preferredColumn = .detail
                } label: {
                  ProductRow(
                    product: product,
                    summary: summary(for: product),
                    isSelected: isSelected
                  )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
              }
              if canLoadMoreInCurrentFilter {
                if let pageError {
                  Text(pageError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                Button {
                  Task { await loadMore() }
                } label: {
                  if loadingMore {
                    ProgressView()
                      .frame(maxWidth: .infinity)
                  } else {
                    Text("Load more products")
                      .fontWeight(.semibold)
                      .frame(maxWidth: .infinity)
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(loadingMore)
                .padding(.top, 6)
              }
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 32)
      .frame(maxWidth: 760)
      .frame(maxWidth: .infinity)
    }
    .scrollEdgeEffectStyle(.soft, for: .top)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Price Checker")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $search, prompt: "Search products")
    .refreshable { await refreshCatalog() }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button { showingFavourites = true } label: { Label("Favourites", systemImage: "heart") }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          ForEach(ProductFilter.allCases) { option in
            Button {
              withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                filter = option
              }
            } label: {
              if filter == option {
                Label("\(option.menuTitle) (Active)", systemImage: "checkmark")
              } else {
                Label(option.menuTitle, systemImage: option.systemImage)
              }
            }
          }
        } label: {
          Label(
            "Filter Products",
            systemImage: filter == .all
              ? "line.3.horizontal.decrease.circle"
              : "line.3.horizontal.decrease.circle.fill"
          )
        }
      }
      .visibilityPriority(.high)

      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await refreshCatalog() }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(loading)
      }
      .visibilityPriority(.low)
    }
  }

  private var emptyFilterTitle: String {
    switch filter {
    case .all: "No products"
    case .decreased: "No price drops found"
    case .increased: "No price rises found"
    case .specials: "No specials in loaded items"
    }
  }

  private var emptyFilterDescription: String {
    switch filter {
    case .all:
      return "Try refreshing to reload tracked products."
    case .decreased:
      return "None of the matching items have dropped in price since the previous recorded check."
    case .increased:
      return "None of the matching items have increased in price since the previous recorded check."
    case .specials:
      return "None of the \(allKnownProducts.count) loaded products are currently marked on special."
    }
  }

  private var priceMovementBanner: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Label("Price Movement Alert", systemImage: "bell.badge.fill")
          .font(.caption.bold())
          .tracking(0.6)
          .foregroundStyle(Theme.brand)
        Spacer()
        Text("Since previous check")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      LazyVGrid(columns: alertColumns, spacing: 10) {
        movementAlertCard(
          title: "Price Drops",
          subtitle: "Reduced",
          count: decreasedCount,
          systemImage: "arrow.down.right.circle.fill",
          tint: Theme.brand,
          surface: Theme.priceDropColumnSurface,
          isSelected: filter == .decreased
        ) {
          withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            filter = filter == .decreased ? .all : .decreased
          }
        }

        movementAlertCard(
          title: "Price Rises",
          subtitle: "Increased",
          count: increasedCount,
          systemImage: "arrow.up.right.circle.fill",
          tint: Theme.priceRise,
          surface: Theme.priceRiseColumnSurface,
          isSelected: filter == .increased
        ) {
          withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            filter = filter == .increased ? .all : .increased
          }
        }
      }
    }
    .padding(14)
    .background(
      Color(uiColor: .secondarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    )
  }

  private func movementAlertCard(
    title: String,
    subtitle: String,
    count: Int,
    systemImage: String,
    tint: Color,
    surface: Color,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(tint)
          Spacer()
          Text("\(count)")
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(tint)
        }
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
        Text("\(subtitle) · Tap to filter")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(
            isSelected ? tint : tint.opacity(0.24),
            lineWidth: isSelected ? 2 : 1
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  @ViewBuilder
  private var detailPane: some View {
    if let product = selectedProduct {
      let snapshotDate: Date? =
        if product.chain == retailer.chain, case .dated(let date) = catalogSnapshot {
          date
        } else {
          nil
        }
      ProductDetail(
        product: product,
        retailerName: GroceryRetailer.displayName(for: product.chain, in: retailers),
        summary: summaries[product.id],
        catalogSnapshotDate: snapshotDate
      )
    } else {
      ContentUnavailableView(
        "Select a product",
        systemImage: "chart.xyaxis.line",
        description: Text(
          "Choose a product to view its latest price, unit price, promotions, and recorded history."
        )
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(uiColor: .systemGroupedBackground))
    }
  }

  private var listHeader: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(search.isEmpty ? "Explore products" : "Search results")
          .font(.title3.bold())
        Spacer()
        if retailers.count == 1, !allKnownProducts.isEmpty {
          Text(retailer.displayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      if !allKnownProducts.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          filterChipsRow
        }
      }
    }
  }

  private var filterChipsRow: some View {
    HStack(spacing: 8) {
      filterButton(
        title: "All (\(allKnownProducts.count)\(hasMore ? "+" : ""))",
        systemImage: ProductFilter.all.systemImage,
        selected: filter == .all,
        activeBackground: Theme.brandSurface,
        activeForeground: Theme.brand
      ) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
          filter = .all
        }
      }
      filterButton(
        title: "Drops (\(decreasedCount))",
        systemImage: ProductFilter.decreased.systemImage,
        selected: filter == .decreased,
        activeBackground: Theme.priceDropColumnSurface,
        activeForeground: Theme.brand
      ) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
          filter = .decreased
        }
      }
      filterButton(
        title: "Rises (\(increasedCount))",
        systemImage: ProductFilter.increased.systemImage,
        selected: filter == .increased,
        activeBackground: Theme.priceRiseColumnSurface,
        activeForeground: Theme.priceRise
      ) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
          filter = .increased
        }
      }
      filterButton(
        title: "Specials (\(specialsCount))",
        systemImage: ProductFilter.specials.systemImage,
        selected: filter == .specials,
        activeBackground: Theme.specialSurface,
        activeForeground: Theme.special
      ) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
          filter = .specials
        }
      }
      Spacer(minLength: 0)
    }
  }

  private func filterButton(
    title: String,
    systemImage: String,
    selected: Bool,
    activeBackground: Color,
    activeForeground: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(selected ? activeForeground : .secondary)
        .background(
          selected ? activeBackground : Color(uiColor: .secondarySystemGroupedBackground),
          in: Capsule()
        )
        .overlay(
          Capsule().strokeBorder(
            selected ? activeForeground.opacity(0.35) : Color.primary.opacity(0.08),
            lineWidth: 1
          )
        )
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  @ViewBuilder
  private var intro: some View {
    let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
    let isCompactBand = verticalSizeClass == .compact || !trimmedSearch.isEmpty
    Group {
      if isCompactBand {
        HStack(spacing: 12) {
          Label("\(retailer.displayName) Price Tracker", systemImage: "basket.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
          Spacer(minLength: 8)
          if !allKnownProducts.isEmpty {
            Text("\(allKnownProducts.count)\(hasMore ? "+" : "") items")
              .font(.caption.weight(.semibold))
              .monospacedDigit()
              .foregroundStyle(Theme.heroAccent)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Label("A SMARTER SHOP", systemImage: "basket.fill")
              .font(.caption.bold())
              .tracking(1.1)
            Spacer()
            Image(systemName: "chart.xyaxis.line")
              .font(.title3)
              .accessibilityHidden(true)
          }
          .foregroundStyle(Theme.heroAccent)

          Text("Know your prices.")
            .font(horizontalSizeClass == .regular ? .title.bold() : .title2.bold())

          Text("Track \(retailer.displayName) price drops, increases, and full history.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.88))

          if !allKnownProducts.isEmpty {
            HStack(spacing: 8) {
              heroMetricPill(
                "\(allKnownProducts.count)\(hasMore ? "+" : "") tracked",
                systemImage: "shippingbox.fill"
              )
              if specialsCount > 0 {
                heroMetricPill("\(specialsCount) on special", systemImage: "tag.fill")
              }
            }
            .padding(.top, 2)
          }
        }
        .padding(16)
      }
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Theme.heroGradient,
      in: RoundedRectangle(cornerRadius: isCompactBand ? 16 : 20, style: .continuous)
    )
    .padding(.top, 6)
  }

  @ViewBuilder
  private var catalogSnapshotStatus: some View {
    let title: LocalizedStringKey? =
      switch catalogSnapshot {
      case .pending: nil
      case .dated(let date):
        "Catalog snapshot as of \(date.formatted(date: .abbreviated, time: .shortened))"
      case .unavailable: "Catalog update time unavailable"
      }
    if let title {
      Label(title, systemImage: "clock")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func heroMetricPill(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .monospacedDigit()
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(.white.opacity(0.14), in: Capsule())
  }

  @MainActor
  private func refreshCatalog() async {
    let currentChain = retailer.chain
    await loadRetailers()
    if !Task.isCancelled, currentChain == retailer.chain { await load() }
  }

  @MainActor
  private func loadRetailers() async {
    guard let available = try? await service.retailers(), !available.isEmpty,
      !Task.isCancelled
    else { return }
    retailers = available
    let selection =
      available.first { $0.chain == retailer.chain }
      ?? available.first { $0.chain == GroceryRetailer.woolworths.chain }
      ?? available[0]
    selectRetailer(selection)
  }

  private var retailerSelection: Binding<String> {
    Binding(
      get: { retailer.chain },
      set: { chain in
        if let selection = retailers.first(where: { $0.chain == chain }) {
          selectRetailer(selection)
        }
      })
  }

  @MainActor
  private func selectRetailer(_ selection: GroceryRetailer) {
    let changed = selection.chain != retailer.chain
    retailer = selection
    guard changed else { return }
    loadID = UUID()
    loadedQuery = nil
    selectedProduct = nil
    preferredColumn = .sidebar
    catalogSnapshot = .pending
    baseProducts = []
    changedProducts = []
    summaries = [:]
    hasMore = false
    loading = true
    loadingMore = false
    error = nil
    pageError = nil
  }

  @MainActor
  private func load(refreshCatalogSnapshot: Bool = true) async {
    let requestID = UUID()
    loadID = requestID
    loading = true
    loadingMore = false
    error = nil
    pageError = nil
    let request = browseQuery
    let isBrowsing = request.search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let shouldFetchSummaries = refreshCatalogSnapshot || isBrowsing || summaries.isEmpty
    let shouldFetchSnapshot = refreshCatalogSnapshot || isBrowsing || catalogSnapshot == .pending
    do {
      async let pageTask = service.products(chain: request.chain, search: request.search, offset: 0)
      async let summariesTask: [UUID: PriceChangeSummary]? =
        shouldFetchSummaries ? (try? service.priceChangeSummaries(chain: request.chain)) : nil
      async let snapshotTask: Date? =
        shouldFetchSnapshot ? (try? service.latestCatalogSnapshot(chain: request.chain)) : nil
      let result = try await pageTask
      let fetchedSummaries = await summariesTask
      var fetchedChanged: [GroceryProduct] = []
      if isBrowsing, let fetchedSummaries {
        let changedIDs = fetchedSummaries.compactMap { id, summary -> UUID? in
          (summary.direction == .decreased || summary.direction == .increased) ? id : nil
        }
        let products = (try? await service.products(ids: changedIDs, chain: request.chain)) ?? []
        fetchedChanged = products.filter { $0.unchangedPriceCheck == nil }
      }
      guard !Task.isCancelled, request == browseQuery, requestID == loadID else { return }
      baseProducts = result
      loadedQuery = request
      if let fetchedSummaries {
        summaries = fetchedSummaries
      }
      if isBrowsing {
        changedProducts = fetchedChanged
      }
      hasMore = result.count == GroceryService.pageSize
      if let current = selectedProduct,
        let updated = allKnownProducts.first(where: { $0.id == current.id })
      {
        selectedProduct = updated
      } else if refreshCatalogSnapshot, let id = selectedProduct?.id {
        let updated = try? await service.products(ids: [id]).first
        guard !Task.isCancelled, request == browseQuery, requestID == loadID else { return }
        if let updated, selectedProduct?.id == id { selectedProduct = updated }
      }
      loading = false
      if shouldFetchSnapshot {
        let date = await snapshotTask
        guard !Task.isCancelled, request == browseQuery, requestID == loadID else { return }
        catalogSnapshot = date.map(CatalogSnapshot.dated) ?? .unavailable
      }
    } catch {
      guard !Task.isCancelled, request == browseQuery, requestID == loadID else { return }
      self.error = error.localizedDescription
      baseProducts = []
      if isBrowsing {
        changedProducts = []
      }
      hasMore = false
      loading = false
    }
  }

  @MainActor
  private func loadMore() async {
    guard !loading, !loadingMore, loadedQuery == browseQuery else { return }
    loadingMore = true
    pageError = nil
    let request = browseQuery
    let requestID = loadID
    defer {
      if requestID == loadID { loadingMore = false }
    }
    do {
      let next = try await service.products(
        chain: request.chain, search: request.search, offset: baseProducts.count)
      guard !Task.isCancelled, request == browseQuery, requestID == loadID else { return }
      baseProducts.append(contentsOf: next)
      hasMore = next.count == GroceryService.pageSize
    } catch {
      if !Task.isCancelled, request == browseQuery, requestID == loadID {
        pageError = error.localizedDescription
      }
    }
  }
}

private struct ProductImage: View {
  let url: URL?
  var size: CGFloat = 68

  var body: some View {
    AsyncImage(url: url) { phase in
      if let image = phase.image {
        image
          .resizable()
          .scaledToFit()
          .frame(width: size, height: size)
          .padding(6)
          .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
          )
      } else {
        Image(systemName: "basket")
          .font(size > 72 ? .title : .title2)
          .foregroundStyle(Theme.brand.opacity(0.75))
          .frame(width: size, height: size)
          .padding(6)
          .background(Theme.brandSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .strokeBorder(Theme.brand.opacity(0.18), lineWidth: 1)
          )
      }
    }
    .accessibilityHidden(true)
  }
}

private struct ProductRow: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let product: GroceryProduct
  let summary: PriceChangeSummary?
  let isSelected: Bool

  private var subtitleText: String? {
    let parts = [product.packageSize, product.cupString]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .top, spacing: 12) {
            ProductImage(url: product.imageURL, size: 60)
            detailsBlock
          }
          priceColumn(fullWidth: true)
        }
      } else {
        HStack(spacing: 10) {
          ProductImage(url: product.imageURL, size: 52)
          detailsBlock
          Spacer(minLength: 4)
          HStack(spacing: 6) {
            priceColumn(fullWidth: false)
            Image(systemName: "chevron.right")
              .font(.caption.weight(.bold))
              .foregroundStyle(.tertiary)
              .accessibilityHidden(true)
          }
        }
      }
    }
    .padding(12)
    .background(
      isSelected ? Theme.brandSurface : Color(uiColor: .secondarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(
          isSelected ? Theme.brand.opacity(0.45) : Color.primary.opacity(0.05),
          lineWidth: isSelected ? 1.5 : 1
        )
    )
    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private var detailsBlock: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let brand = product.brand, !brand.isEmpty {
        Text(brand.uppercased())
          .font(.caption2.weight(.bold))
          .tracking(0.6)
          .foregroundStyle(.secondary)
      }
      Text(product.name)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
      if let subtitleText {
        Text(subtitleText)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      if summary?.direction == .increased || summary?.direction == .decreased || product.isOnSpecial
        || product.isAvailable == false
      {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 6) {
            rowBadges
          }
          VStack(alignment: .leading, spacing: 4) {
            rowBadges
          }
        }
        .padding(.top, 2)
      }
    }
  }

  @ViewBuilder
  private var rowBadges: some View {
    if summary?.direction == .increased {
      BadgePill(
        title: "Price increased",
        systemImage: "arrow.up.right.circle.fill",
        foreground: Theme.priceRise,
        background: Theme.priceRiseColumnSurface
      )
    } else if summary?.direction == .decreased {
      BadgePill(
        title: "Price dropped",
        systemImage: "arrow.down.right.circle.fill",
        foreground: Theme.brand,
        background: Theme.priceDropColumnSurface
      )
    }
    if product.isOnSpecial {
      BadgePill(
        title: "Special",
        systemImage: "tag.fill",
        foreground: Theme.special,
        background: Theme.specialSurface
      )
    }
    if product.isAvailable == false {
      BadgePill(
        title: "Unavailable",
        systemImage: "exclamationmark.circle.fill",
        foreground: .secondary,
        background: Color.primary.opacity(0.07)
      )
    }
  }

  private func priceColumn(fullWidth: Bool) -> some View {
    let direction = summary?.direction
    let columnBackground: Color =
      switch direction {
      case .increased: Theme.priceRiseColumnSurface
      case .decreased: Theme.priceDropColumnSurface
      default: Color(uiColor: .tertiarySystemGroupedBackground)
      }
    let columnBorder: Color =
      switch direction {
      case .increased: Theme.priceRise.opacity(0.28)
      case .decreased: Theme.brand.opacity(0.28)
      default: Color.primary.opacity(0.06)
      }
    let priceColor: Color =
      switch direction {
      case .increased: Theme.priceRise
      case .decreased: Theme.brand
      default: product.price != nil ? Theme.brand : .secondary
      }

    return VStack(alignment: fullWidth ? .leading : .trailing, spacing: 3) {
      if let delta = summary?.delta, direction == .increased || direction == .decreased {
        HStack(spacing: 3) {
          Image(
            systemName: direction == .increased
              ? "arrow.up.right.circle.fill"
              : "arrow.down.right.circle.fill"
          )
          Text("\(direction == .increased ? "+" : "-")\(money(abs(delta)))")
        }
        .font(.caption2.bold().monospacedDigit())
        .foregroundStyle(direction == .increased ? Theme.priceRise : Theme.brand)
      } else {
        HStack(spacing: 3) {
          Image(systemName: direction == .unchanged ? "equal.circle.fill" : "clock")
          Text(direction == .unchanged ? "Unchanged" : "Tracked")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
      }

      Text(product.price.map(money) ?? "—")
        .font(.headline.weight(.bold).monospacedDigit())
        .foregroundStyle(priceColor)

      if let prev = summary?.previousPrice, direction == .increased || direction == .decreased {
        HStack(spacing: 3) {
          Image(systemName: "clock.arrow.circlepath")
          Text("Prev \(money(prev))")
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
      } else if let was = product.wasPrice, let price = product.price, was > price {
        Text(money(was))
          .font(.caption2.monospacedDigit())
          .strikethrough()
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 8)
    .frame(minWidth: fullWidth ? nil : 90, alignment: fullWidth ? .leading : .trailing)
    .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
    .background(columnBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(columnBorder, lineWidth: 1)
    )
  }
}

private struct BadgePill: View {
  let title: String
  let systemImage: String
  let foreground: Color
  let background: Color

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(foreground)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(background, in: Capsule())
  }
}

private func money(_ value: Double) -> String {
  value.formatted(.currency(code: "AUD"))
}

private struct ProductDetail: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let product: GroceryProduct
  let retailerName: String
  let summary: PriceChangeSummary?
  let catalogSnapshotDate: Date?

  @State private var records: [PriceRecord] = []
  @State private var loading = true
  @State private var error: String?
  @State private var period: Period = .all
  @State private var selectedDate: Date?
  @State private var division: DivisionLayout = .none
  @State private var loadTask: Task<Void, Never>?
  @State private var loadedProductID: UUID?
  @State private var loadToken: UUID?

  private let service = GroceryService()

  private var priceComparison: PriceChangeSummary? {
    let recorded = records.last.map { last in
      PriceChangeSummary(previousPrice: records.dropLast().last?.price, latestPrice: last.price)
    }
    return product.latestPriceComparison(recorded: recorded ?? summary)
  }

  private var chartAccent: Color {
    if priceComparison?.direction == .increased {
      return Theme.priceRise
    }
    return Theme.brand
  }

  enum Period: String, CaseIterable, Identifiable {
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    var months: Int? {
      switch self {
      case .month: 1
      case .threeMonths: 3
      case .year: 12
      case .all: nil
      }
    }
  }

  private var priced: [PriceRecord] {
    records.filter { $0.price != nil }
  }

  private var insights: PriceHistoryInsights {
    PriceHistoryInsights(records: records)
  }

  private var periodCutoff: Date? {
    period.months.flatMap { Calendar.current.date(byAdding: .month, value: -$0, to: Date()) }
  }

  private var lastProductCheckDate: Date {
    max(product.scrapedAt, product.lastSeenAt ?? product.scrapedAt)
  }

  private var laterCatalogSnapshot: Date? {
    let calendar = Calendar.current
    guard let catalogSnapshotDate,
      calendar.startOfDay(for: catalogSnapshotDate) > calendar.startOfDay(for: lastProductCheckDate)
    else { return nil }
    return catalogSnapshotDate
  }

  private var latestPricedRecord: PriceRecord? {
    guard let last = records.last, last.scrapedAt == product.scrapedAt,
      let price = last.price, price == product.price
    else { return nil }
    return last
  }

  private var displayed: [PriceRecord] {
    guard let cutoff = periodCutoff else { return priced }
    let newer = priced.filter { $0.scrapedAt >= cutoff }
    let catalogReachesRange = laterCatalogSnapshot.map { $0 > cutoff } ?? false
    // Include the preceding observation when its price reaches the window.
    if let previous = records.last(where: { $0.scrapedAt < cutoff }), previous.price != nil,
      lastProductCheckDate >= cutoff
        || (catalogReachesRange && latestPricedRecord?.id == previous.id)
    {
      return [previous] + newer
    }
    return newer
  }

  private var hasUnknownPrices: Bool {
    records.contains { $0.price == nil }
  }

  private var chartYDomain: ClosedRange<Double>? {
    let prices = displayed.compactMap(\.price)
    guard let minPrice = prices.min(), let maxPrice = prices.max() else { return nil }
    let span = max(maxPrice - minPrice, max(maxPrice * 0.05, 0.5))
    let lower = max(0, minPrice - span * 0.25)
    let upper = maxPrice + span * 0.35
    return lower...upper
  }

  private var plottedUnchangedCheck: UnchangedPriceCheck? {
    guard let last = latestPricedRecord, displayed.last?.id == last.id,
      let checked = product.unchangedPriceCheck,
      checked.date >= plottedDate(for: last, cutoff: periodCutoff)
    else { return nil }
    return checked
  }

  private var carriedPrice: (price: Double, from: Date, to: Date)? {
    guard let end = laterCatalogSnapshot, let last = latestPricedRecord,
      displayed.last?.id == last.id, let price = last.price
    else { return nil }
    let start = max(lastProductCheckDate, plottedDate(for: last, cutoff: periodCutoff))
    guard start < end else { return nil }
    return (price, start, end)
  }

  private var chartDateSpan: ClosedRange<Date>? {
    let cutoff = periodCutoff
    guard let first = displayed.first, let last = displayed.last else { return nil }
    let lastPlotted = plottedDate(for: last, cutoff: cutoff)
    let end = max(lastPlotted, laterCatalogSnapshot ?? lastProductCheckDate)
    return plottedDate(for: first, cutoff: cutoff)...end
  }

  private var chartXDomain: ClosedRange<Date> {
    guard let dates = chartDateSpan else {
      let now = Date()
      return now.addingTimeInterval(-86_400)...now
    }
    let first = dates.lowerBound
    let last = dates.upperBound
    let span = last.timeIntervalSince(first)
    if span == 0 {
      return first.addingTimeInterval(-43_200)...first.addingTimeInterval(43_200)
    }
    let pad = max(3_600, span * 0.12)
    return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
  }

  private var scrubbedMatch: (price: Double, plottedDate: Date, observedAt: Date, unchanged: Bool)?
  {
    guard let selectedDate, !displayed.isEmpty else { return nil }
    let cutoff = periodCutoff
    let match = displayed.min { lhs, rhs in
      abs(plottedDate(for: lhs, cutoff: cutoff).timeIntervalSince(selectedDate))
        < abs(plottedDate(for: rhs, cutoff: cutoff).timeIntervalSince(selectedDate))
    }
    guard let nearest = match, let price = nearest.price else { return nil }
    let position = plottedDate(for: nearest, cutoff: cutoff)
    if let check = plottedUnchangedCheck,
      abs(check.date.timeIntervalSince(selectedDate))
        <= abs(position.timeIntervalSince(selectedDate))
    {
      return (check.price, check.date, check.date, true)
    }
    return (price, position, nearest.scrapedAt, false)
  }

  private var statColumns: [GridItem] {
    let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
    let spacing: CGFloat = division.isVertical ? max(16, division.width + 16) : 12
    return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if division.isVertical {
          HStack(alignment: .top, spacing: max(20, division.width + 16)) {
            header
              .frame(maxWidth: .infinity, alignment: .topLeading)
            historyCard
              .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          header
          historyCard
        }

        if !records.isEmpty {
          snapshotsCard
        }

        Text(
          "Prices and availability may vary by location and can change. Check the retailer before shopping."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(20)
      .frame(maxWidth: 840)
      .frame(maxWidth: .infinity)
    }
    .scrollEdgeEffectStyle(.soft, for: .top)
    .background(Color(uiColor: .systemGroupedBackground))
    .toolbar { ToolbarItem(placement: .topBarTrailing) { FavouriteButton(productID: product.id) } }
    .navigationTitle("Product details")
    .navigationBarTitleDisplayMode(.inline)
    .onGeometryChange(for: DivisionLayout.self) { proxy in
      if let region = proxy.reservedRegions(kind: .division).first {
        return DivisionLayout(
          isVertical: region.frame.height > region.frame.width,
          width: region.frame.width + region.margins.leading + region.margins.trailing
        )
      }
      return .none
    } action: { newValue in
      division = newValue
    }
    .onChange(of: period) { _, _ in
      selectedDate = nil
    }
    .onAppear {
      ensureLoaded()
    }
    .onChange(of: product) { old, new in
      if old.id != new.id || old.scrapedAt != new.scrapedAt { reloadHistory() }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        ProductImage(url: product.imageURL, size: 84)
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Text(retailerName.uppercased())
              .font(.caption2.bold())
              .tracking(1)
              .foregroundStyle(Theme.brand)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Theme.brandSurface, in: Capsule())
            if let brand = product.brand, !brand.isEmpty {
              Text(brand)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
          }
          Text(product.name)
            .font(.title2.bold())
          if let size = product.packageSize, !size.isEmpty {
            Text(size)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }

      Divider()

      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(product.price.map(money) ?? "Price unavailable")
          .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
          .foregroundStyle(product.price != nil ? chartAccent : .secondary)
        if let was = product.wasPrice, let price = product.price, was > price {
          Text(money(was))
            .font(.title3.monospacedDigit())
            .strikethrough()
            .foregroundStyle(.secondary)
          BadgePill(
            title: "Save \(money(was - price))",
            systemImage: "arrow.down.right",
            foreground: Theme.special,
            background: Theme.specialSurface
          )
        }
        Spacer(minLength: 0)
      }

      if priceComparison?.direction == .unchanged {
        Label("Price unchanged", systemImage: "equal.circle.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
      } else if let change = priceComparison?.delta, abs(change) > 0.005 {
        let isIncrease = change > 0
        HStack(spacing: 12) {
          Image(
            systemName: isIncrease
              ? "arrow.up.right.circle.fill"
              : "arrow.down.right.circle.fill"
          )
          .font(.title3)
          .foregroundStyle(isIncrease ? Theme.priceRise : Theme.brand)

          VStack(alignment: .leading, spacing: 2) {
            Text(
              isIncrease
                ? "Price increased by \(money(change))"
                : "Price reduced by \(money(abs(change)))"
            )
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(isIncrease ? Theme.priceRise : Theme.brand)

            if let prev = priceComparison?.previousPrice {
              Text("From \(money(prev)) at previous recorded check")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          Spacer(minLength: 0)
        }
        .padding(12)
        .background(
          isIncrease ? Theme.priceRiseColumnSurface : Theme.priceDropColumnSurface,
          in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
              (isIncrease ? Theme.priceRise : Theme.brand).opacity(0.28),
              lineWidth: 1
            )
        )
      }

      VStack(alignment: .leading, spacing: 6) {
        if let unit = product.cupString, !unit.isEmpty {
          Label(unit, systemImage: "scalemass")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        if let promotion = product.promotion, !promotion.isEmpty {
          Label(promotion, systemImage: "tag.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.special)
        }
        if product.isAvailable == false {
          Label("Unavailable when recorded", systemImage: "exclamationmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if let date = product.lastSeenAt {
          Label {
            Text("Last checked \(date.formatted(date: .abbreviated, time: .shortened))")
          } icon: {
            Image(systemName: "clock")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        if let region = product.region, !region.isEmpty {
          Label("Source region: \(region)", systemImage: "mappin.and.ellipse")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if let url = product.url, url.scheme == "https" {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 10) {
            Link(destination: url) {
              Label("View at \(retailerName)", systemImage: "arrow.up.right.square.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            ShareLink(item: url) {
              Label("Share", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
          }

          VStack(spacing: 8) {
            Link(destination: url) {
              Label("View at \(retailerName)", systemImage: "arrow.up.right.square.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            ShareLink(item: url) {
              Label("Share Product", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
          }
        }
      }
    }
    .card()
  }

  private var historyCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        if let matched = scrubbedMatch {
          let date = matched.observedAt.formatted(date: .abbreviated, time: .shortened)
          let title: LocalizedStringKey =
            matched.unchanged ? "Price unchanged · \(date)" : "Recorded \(date)"
          VStack(alignment: .leading, spacing: 4) {
            Text(money(matched.price))
              .font(.title2.bold().monospacedDigit())
              .foregroundStyle(chartAccent)
            Text(title)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } else {
          VStack(alignment: .leading, spacing: 4) {
            Text("PRICE HISTORY")
              .font(.caption.bold())
              .tracking(1)
              .foregroundStyle(.secondary)
            Text("The bigger picture")
              .font(.title2.bold())
          }
        }
        Spacer()
        Image(systemName: "chart.line.uptrend.xyaxis")
          .foregroundStyle(chartAccent)
          .font(.title2)
          .accessibilityHidden(true)
      }

      if loading {
        ProgressView("Loading history…")
          .frame(maxWidth: .infinity)
          .padding(40)
      } else if let error {
        ContentUnavailableView {
          Label("Couldn’t load history", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
          Button("Try again") { reloadHistory() }
            .buttonStyle(.bordered)
        }
      } else if priced.isEmpty {
        Text("No recorded prices yet.")
          .foregroundStyle(.secondary)
          .padding(.vertical)
      } else {
        Picker("Time range", selection: $period) {
          ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)

        chart

        if let date = product.lastSeenAt {
          Label(
            "Last checked \(date.formatted(date: .abbreviated, time: .shortened))",
            systemImage: "clock"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        if carriedPrice != nil {
          Text("The dashed segment carries forward the last known price.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let lowest = insights.lowest, let highest = insights.highest {
          LazyVGrid(columns: statColumns, alignment: .leading, spacing: 12) {
            historyStatistic(
              "Lowest recorded",
              value: money(lowest),
              systemImage: "arrow.down.circle.fill",
              tint: Theme.brand
            )
            historyStatistic(
              "Highest recorded",
              value: money(highest),
              systemImage: "arrow.up.circle.fill",
              tint: .primary
            )
            historyStatistic(
              "Latest recorded",
              value: product.price.map(money) ?? "—",
              systemImage: "tag.fill",
              tint: Theme.brand
            )
            historyStatistic(
              "Price snapshots",
              value: "\(insights.pricedCount)",
              systemImage: "chart.bar.fill",
              tint: .secondary
            )
          }

          Text("Across all recorded history, regardless of the selected chart range.")
            .font(.caption)
            .foregroundStyle(.secondary)

          if insights.pricedCount == 1 {
            Text(
              "Only one price snapshot is available so far; comparisons will appear as more changes are recorded."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }

        Text(
          "Snapshots record the first observation and later changes. The chart also shows the most recent confirmed check when the price stayed the same."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .card()
  }

  private var snapshotsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Recorded snapshots")
          .font(.title2.bold())
        Text("All recorded history, newest first.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      LazyVStack(alignment: .leading, spacing: 14) {
        ForEach(insights.entries.reversed()) { entry in
          HistorySnapshotView(entry: entry)
          if entry.id != records.first?.id {
            Divider()
          }
        }
      }
    }
    .card()
  }

  private func historyStatistic(
    _ title: String,
    value: String,
    systemImage: String,
    tint: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(title, systemImage: systemImage)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.headline.bold().monospacedDigit())
        .foregroundStyle(tint)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
      Color(uiColor: .tertiarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
  }

  private var chart: some View {
    let first = displayed.first
    let last = displayed.last
    let cutoff = periodCutoff
    let check = plottedUnchangedCheck
    let domain = chartYDomain
    let xDomain = chartXDomain
    let baseline = domain?.lowerBound ?? 0
    let dates = chartDateSpan ?? xDomain
    let calendar = Calendar.current
    let spansMultipleDays = !calendar.isDate(dates.lowerBound, inSameDayAs: dates.upperBound)
    let granularity: Calendar.Component = spansMultipleDays ? .day : .minute
    let midpoint = dates.lowerBound.addingTimeInterval(
      dates.upperBound.timeIntervalSince(dates.lowerBound) / 2)
    var axisDates = [dates.upperBound]
    for date in [dates.lowerBound, midpoint] {
      let overlaps = axisDates.contains {
        calendar.isDate($0, equalTo: date, toGranularity: granularity)
      }
      if !overlaps { axisDates.insert(date, at: axisDates.count - 1) }
    }
    let showPointAnnotations = displayed.count <= 6 && selectedDate == nil
    let fill = LinearGradient(
      colors: [chartAccent.opacity(0.22), chartAccent.opacity(0.02)],
      startPoint: .top,
      endPoint: .bottom)

    return Chart {
      if let lowest = insights.lowest, let highest = insights.highest, lowest < highest {
        RuleMark(y: .value("Price", lowest))
          .foregroundStyle(Theme.brand.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
      }

      ForEach(displayed) { item in
        if let price = item.price {
          let date = plottedDate(for: item, cutoff: cutoff)
          if !hasUnknownPrices {
            AreaMark(
              x: .value("Date", date),
              yStart: .value("Price", baseline),
              yEnd: .value("Price", price)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(fill)

            LineMark(x: .value("Date", date), y: .value("Price", price))
              .interpolationMethod(.linear)
              .lineStyle(StrokeStyle(lineWidth: 2.5))
              .foregroundStyle(chartAccent)
          }

          if date == item.scrapedAt || date <= lastProductCheckDate {
            PointMark(x: .value("Date", date), y: .value("Price", price))
              .foregroundStyle(chartAccent)
              .symbolSize(64)
              .annotation(
                position: .top,
                spacing: 6,
                overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))
              ) {
                if showPointAnnotations {
                  Text(money(price))
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(chartAccent)
                }
              }
              .accessibilityLabel(item.scrapedAt.formatted(date: .abbreviated, time: .shortened))
              .accessibilityValue(money(price))
          }
        }
      }

      if let last, let check {
        let from = plottedDate(for: last, cutoff: cutoff)
        if check.date > from {
          if hasUnknownPrices {
            LineMark(x: .value("Date", from), y: .value("Price", check.price))
              .lineStyle(StrokeStyle(lineWidth: 2.5))
              .foregroundStyle(chartAccent)
          } else {
            AreaMark(
              x: .value("Date", check.date),
              yStart: .value("Price", baseline),
              yEnd: .value("Price", check.price)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(fill)
          }
          LineMark(x: .value("Date", check.date), y: .value("Price", check.price))
            .interpolationMethod(.linear)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .foregroundStyle(chartAccent)
          PointMark(x: .value("Date", check.date), y: .value("Price", check.price))
            .foregroundStyle(chartAccent)
            .symbolSize(64)
            .accessibilityLabel(
              "Price unchanged on \(check.date.formatted(date: .abbreviated, time: .shortened))"
            )
            .accessibilityValue(money(check.price))
        }
      }

      if let carry = carriedPrice {
        RuleMark(
          xStart: .value("From", carry.from),
          xEnd: .value("Through catalog snapshot", carry.to),
          y: .value("Last known price", carry.price)
        )
        .foregroundStyle(Color.secondary)
        .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
        .accessibilityLabel("Last known price carried forward")
        .accessibilityValue(money(carry.price))
      }

      if let selectedDate, let matched = scrubbedMatch {
        RuleMark(x: .value("Date", selectedDate))
          .foregroundStyle(chartAccent.opacity(0.45))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        let isObservedDate = matched.plottedDate == matched.observedAt
        if isObservedDate || matched.plottedDate <= lastProductCheckDate {
          PointMark(x: .value("Date", matched.plottedDate), y: .value("Price", matched.price))
            .foregroundStyle(chartAccent)
            .symbolSize(100)
        }
      }
    }
    .chartXSelection(value: $selectedDate)
    .chartXScale(domain: xDomain)
    .chartYScale(domain: domain ?? 0...1)
    .chartXAxis {
      AxisMarks(values: axisDates) { _ in
        AxisGridLine()
        AxisTick()
        if spansMultipleDays {
          AxisValueLabel(format: .dateTime.day().month(.abbreviated))
        } else {
          AxisValueLabel(format: .dateTime.hour().minute())
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading) { _ in
        AxisGridLine()
        AxisValueLabel(format: .currency(code: "AUD"))
      }
    }
    .frame(minHeight: 220, maxHeight: 280)
    .accessibilityLabel("Price history chart")
    .accessibilityHint("Touch and drag across the chart to inspect prices and confirmed checks.")
    .overlay {
      if first == nil {
        Text("No prices in this period")
          .foregroundStyle(.secondary)
      }
    }
  }

  private func plottedDate(for record: PriceRecord, cutoff: Date?) -> Date {
    cutoff.map { max($0, record.scrapedAt) } ?? record.scrapedAt
  }

  private func ensureLoaded() {
    if loadedProductID != product.id || (loading && loadTask == nil) {
      reloadHistory()
    }
  }

  @MainActor
  private func reloadHistory() {
    loadTask?.cancel()
    let targetID = product.id
    let token = UUID()
    loadToken = token
    loadedProductID = targetID
    loading = true
    error = nil
    selectedDate = nil
    records = []

    loadTask = Task { @MainActor in
      defer {
        if loadToken == token {
          loadTask = nil
        }
      }
      do {
        let fetched = try await service.history(productID: targetID)
        guard !Task.isCancelled, loadToken == token else { return }
        records = fetched
        loading = false
      } catch {
        guard !Task.isCancelled, loadToken == token else { return }
        self.error = error.localizedDescription
        loading = false
      }
    }
  }
}

private struct HistorySnapshotView: View {
  let entry: HistoryEntry
  private var record: PriceRecord { entry.record }

  private var unitPriceDescription: String? {
    if let text = record.unitPriceText, !text.isEmpty { return text }
    guard let price = record.unitPrice, let measure = record.unitMeasure, !measure.isEmpty else {
      return nil
    }
    return "\(money(price)) / \(measure)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(record.scrapedAt, format: .dateTime.day().month(.abbreviated).year())
            .font(.subheadline.weight(.semibold))
          Text(record.scrapedAt, format: .dateTime.hour().minute())
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        Text(record.price.map(money) ?? "Price unavailable")
          .font(.subheadline.bold().monospacedDigit())
          .foregroundStyle(record.price != nil ? .primary : .secondary)
          .multilineTextAlignment(.trailing)
      }

      if let change = entry.priceChange {
        if abs(change) < 0.005 {
          Label("Price unchanged since previous snapshot", systemImage: "equal.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          let isDrop = change < 0
          BadgePill(
            title: "\(isDrop ? "Down" : "Up") \(money(abs(change))) since previous snapshot",
            systemImage: isDrop ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill",
            foreground: isDrop ? Theme.brand : Theme.priceRise,
            background: isDrop ? Theme.priceDropColumnSurface : Theme.priceRiseColumnSurface
          )
        }
      }

      if record.isHalfPrice || record.isOnSpecial {
        BadgePill(
          title: record.isHalfPrice ? "Half price" : "Special",
          systemImage: "tag.fill",
          foreground: Theme.special,
          background: Theme.specialSurface
        )
      }

      if let promotion = record.promotion, !promotion.isEmpty {
        Text(promotion)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let savings = record.savingsAmount, savings > 0 {
        Text("Retailer saving: \(money(savings))")
          .font(.caption.weight(.medium).monospacedDigit())
          .foregroundStyle(Theme.brand)
      }

      DisclosureGroup("Snapshot details") {
        VStack(alignment: .leading, spacing: 8) {
          if let was = record.wasPrice {
            detail("Retailer’s was price", value: money(was))
          }
          if let discount = record.discountPercent, discount > 0 {
            detail(
              "Discount",
              value: "\(discount.formatted(.number.precision(.fractionLength(0...2))))%"
            )
          }
          if let unit = unitPriceDescription {
            detail("Unit price", value: unit)
          }
          if record.isMultibuy {
            detail("Offer type", value: "Multibuy")
          }
          if let limit = record.productLimit, limit > 0 {
            detail("Order limit", value: "\(limit)")
          }
          if let available = record.isAvailable {
            detail(
              "Availability",
              value: available ? "Available when recorded" : "Unavailable when recorded"
            )
          }
          if let region = record.region, !region.isEmpty {
            detail("Source region", value: region)
          }
          if record.wasPrice != nil {
            Text("The retailer’s was price may differ from the previous snapshot price.")
              .foregroundStyle(.secondary)
          }
          Text("Details reflect this recorded snapshot and may have changed since.")
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.top, 8)
      }
      .font(.caption.weight(.medium))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func detail(_ title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer(minLength: 8)
      Text(value)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
  }
}

extension View {
  fileprivate func card() -> some View {
    self.padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Color(uiColor: .secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
      )
  }
}
