# Papa PriceChecker

A native SwiftUI app for browsing the Woolworths products tracked by the existing grocery-price pipeline. Upon launch, a Price Movement Alert summarizes how many tracked items dropped or increased since their previous recorded snapshot and brings price-changed items to the top of the list. Each product row highlights price increases in gentle red and price reductions in gentle green with directional icons. Search by product name, filter by All, Drops, Rises, or Specials, open a product to see its latest recorded price, unit price, promotion and price history, choose a chart range, and scrub across the chart to inspect recorded snapshots. Results are loaded in pages. The app uses `NavigationSplitView` to present a single-column flow in compact width (iPhone and the iPhone Duo outer display) and side-by-side browse/detail columns in regular width (iPhone Duo inner display and iPad), supports Dynamic Type through system text styles, and adapts to Light, Dark, and High Contrast appearances.

For the app architecture, data flow, Supabase access and database schema, see [implementation.md](implementation.md).

## Open and run

Open `Papa PriceChecker.xcodeproj` in Xcode 27.2 or later and run the `Papa PriceChecker` scheme on an iOS 27.2 simulator or device. The deployment target was inherited from the new Xcode project. Xcode and the Apple SDK are required; they cannot be supplied by a normal Linux container. No dependency installation is necessary. For a command-line unsigned build:

```sh
xcodebuild -project 'Papa PriceChecker.xcodeproj' -scheme 'Papa PriceChecker' \
  -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

The app icon is supplied as a 1024 × 1024 universal iOS asset in `Assets.xcassets/AppIcon.appiconset`; Xcode produces the device-specific sizes during the build. Dark and tinted appearances use the system-generated treatment. `Assets.xcassets/AccentColor.colorset` defines adaptive Light and Dark accent colors.

## Data and access

`GroceryService.swift` uses read-only HTTPS requests to the existing Supabase PostgREST API. It reads `v_latest_prices` for browsing and `price_history` for the selected product. The URL and **publishable** key come from the grocery actor's `architecture.md`; the publishable key is intended for public clients and is not a secret. Never add a Supabase secret or service-role key to the app. The grocery backend owns its schema, database grants and row-level security. Its migrations define anonymous SELECT access and security-invoker views; keep write access restricted and review the deployed policies independently before release. No backend changes are made by this app.

No login is required for the public product and price data. An account would only be needed for features such as private, cross-device saved lists. Search covers products collected by the pipeline, not the retailer's entire catalogue. Product availability, promotions and prices may depend on region and may change after a scrape.

## Understanding history

The ingestion pipeline adds a history record when a product is first seen or its price, promotion or availability changes; it does not create a record for every daily check. The app displays the product's `last_seen_at` as “Last checked” and the timestamp on each history row as the time that state was recorded. The chart uses a trend line to show recorded prices and extends the last known price only to the most recent check. If any historical price is unavailable, it displays points without joining across the unknown period. A range can include the last known observation before its start so a price that continued into that range is visible. A daily 9 am schedule is an upstream operational schedule, not a guarantee that a particular product has been checked successfully.

The history card shows the lowest, highest, and latest recorded prices alongside the count of snapshots with a price in an even two-column grid across all history, independent of the selected chart range. Each snapshot can show the change from the immediately preceding recorded price, the retailer's promotion and saving, and expandable details such as its was price, discount percentage, unit price, multibuy flag, order limit, availability and source region. A retailer's was price is not necessarily the preceding recorded price. Missing values are omitted; a missing price prevents comparison across that snapshot. The pipeline does not create a new row solely because unit price, order limit, multibuy status or region changes, so those details describe the snapshot and are not guaranteed to have been rechecked on the last-seen date.

Run the local history decoding and calculation checks with:

```sh
xcrun swiftc -module-cache-path /tmp/papa-pricechecker-swift-modules \
  'Papa PriceChecker/GroceryService.swift' 'Papa PriceChecker/PriceHistoryInsights.swift' \
  Tests/PriceHistoryChecks.swift -o /tmp/papa-pricechecker-history-checks
/tmp/papa-pricechecker-history-checks
```

## Verification and design

The layout uses `NavigationSplitView` (`.balanced`), standard system toolbars with titles, symbols, and `visibilityPriority`, `reservedRegions(kind: .division)` checks in `ProductDetail`, compact-height hero sizing, and an even two-column statistics grid without fixed screen dimensions, guided by Apple's [iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) and [iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) guidance. Confirm expanded split layouts, fold transitions, accessibility sizes, VoiceOver, dark mode, and live images on simulators and physical devices before release. The source project is `/Users/fernandodeleon/dev/NandoProjects/GroceryActor-apify/woolworths-actor`.
