//
//  Papa_PriceCheckerApp.swift
//  Papa PriceChecker
//
//  Created by Fernando De Leon on 17/11/2026.
//

import SwiftUI

@main
struct Papa_PriceCheckerApp: App {
  @State private var account = AccountStore()
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(account)
        .task { await account.observeSession() }
    }
  }
}
