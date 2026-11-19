# Papa PriceChecker

A native SwiftUI app for browsing products tracked by the grocery-price pipeline. Woolworths is the initial retailer. A retailer picker appears when Supabase lists multiple enabled retailers. Upon launch, a Price Movement Alert summarizes how many tracked items dropped or increased since their previous recorded snapshot and brings price-changed items to the top of the list. Each product row highlights price increases in gentle red and price reductions in gentle green with directional icons. Search by product name, filter by All, Drops, Rises, or Specials, open a product to see its latest recorded price, unit price, promotion and price history, choose a chart range, and scrub across the chart to inspect recorded snapshots. Results are loaded in pages. The app uses `NavigationSplitView` to present a single-column flow in compact width (iPhone and the iPhone Duo outer display) and side-by-side browse/detail columns in regular width (iPhone Duo inner display and iPad), supports Dynamic Type through system text styles, and adapts to Light, Dark, and High Contrast appearances.

For the app architecture, data flow, Supabase access and database schema, see [implementation.md](implementation.md).

## Open and run

Open `Papa PriceChecker.xcodeproj` in Xcode 27.2 or later and run the `Papa PriceChecker` scheme on an iOS 27.2 simulator or device. The deployment target was inherited from the new Xcode project. Xcode and the Apple SDK are required; they cannot be supplied by a normal Linux container. Xcode resolves the pinned Supabase Swift package automatically. For a command-line unsigned build:

```sh
xcodebuild -project 'Papa PriceChecker.xcodeproj' -scheme 'Papa PriceChecker' \
  -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

The app icon is supplied as a 1024 × 1024 universal iOS asset in `Assets.xcassets/AppIcon.appiconset`; Xcode produces the device-specific sizes during the build. Dark and tinted appearances use the system-generated treatment. `Assets.xcassets/AccentColor.colorset` defines adaptive Light and Dark accent colors.

## Data and access

`GroceryService.swift` uses read-only HTTPS requests to the Supabase PostgREST API. It reads `retailers` for enabled chains, filters `v_latest_prices` by chain for browsing, calls `search_products_by_chain` for ranked search, and reads `price_history` by product ID for detail. The app falls back to the existing Woolworths search during rollout. The URL and **publishable** key come from the grocery actor's `architecture.md`. The grocery backend owns its schema, database grants and row-level security. See [retailer rollout](implementation.md#retailer-rollout) for the staging setup.

Browsing public product and price data does not require login. The phase-one client adds optional Sign in with Apple and private, synced favourites. The favourites table has been applied to the live project, and the deletion function has been deployed; the Apple provider is enabled, and the user has confirmed sign-in on an iPhone. The user also confirmed that a favourite persists after reopening the app; cross-device syncing and account-deletion validation remain pending; see [phase-one setup](backend/phase1/README.md) before attempting sign-in or releasing the feature. Search covers products collected by the pipeline, not the retailer's entire catalogue. Product availability, promotions and prices may depend on region and may change after a scrape.

## Accounts and favourites

Tap the heart on a product to sign in with Apple and save it. The Favourites toolbar button opens the saved list and account actions. A signed-in user can remove favourites, sign out on the current device, or request account deletion after reauthorizing with Apple. Account deletion requires the separate backend function, Apple signing credentials and server configuration described in the phase-one setup. No notification or alert delivery is implemented in this phase.

## Understanding history

Above the product list, **Catalog snapshot as of** shows when the selected retailer’s latest successfully imported scrape finished, in your device’s local time. The date is checked on launch, on refresh, and when switching retailers, including when the import found no price changes. Each product’s **Last checked** timestamp shows when that particular item was seen.

The ingestion pipeline adds a history record when a product is first seen or its price, promotion or availability changes. When a later check confirms the same price, the app shows **Price unchanged** and draws a solid flat segment through the product’s **Last checked** date. If the catalog has a newer snapshot, a dashed segment carries the last known price forward to that date. Only recorded snapshots contribute to the snapshot count.

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
