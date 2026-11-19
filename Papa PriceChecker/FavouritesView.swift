import AuthenticationServices
import SwiftUI

struct FavouriteButton: View {
  @Environment(AccountStore.self) private var account
  let productID: UUID
  @State private var showingSignIn = false
  @State private var error: String?

  var body: some View {
    Button {
      if account.isSignedIn {
        Task { await toggle() }
      } else {
        showingSignIn = true
      }
    } label: {
      Label(
        account.favouriteIDs.contains(productID) ? "Remove from favourites" : "Add to favourites",
        systemImage: account.favouriteIDs.contains(productID) ? "heart.fill" : "heart"
      )
    }
    .disabled(account.busyIDs.contains(productID))
    .sheet(isPresented: $showingSignIn) {
      AppleSignInView {
        if !account.favouriteIDs.contains(productID) {
          try await account.toggleFavourite(productID)
        }
      }
    }
    .alert(
      "Couldn’t update favourite",
      isPresented: Binding(
        get: { error != nil }, set: { if !$0 { error = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "Please try again.")
    }
  }

  private func toggle() async {
    if !account.favouritesLoaded || account.loadingFavourites { await account.refreshFavourites() }
    do { try await account.toggleFavourite(productID) } catch {
      self.error = error.localizedDescription
    }
  }
}

struct AppleSignInView: View {
  @Environment(AccountStore.self) private var account
  @Environment(\.dismiss) private var dismiss
  var afterSignIn: (() async throws -> Void)? = nil
  @State private var busy = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Image(systemName: "heart.circle.fill").font(.system(size: 56)).foregroundStyle(.tint)
        Text("Keep your favourites together").font(.title2.bold()).multilineTextAlignment(.center)
        Text("Sign in with Apple to save products and access them on your devices.")
          .foregroundStyle(.secondary).multilineTextAlignment(.center)
        if busy { ProgressView("Signing in…") }
        SignInWithAppleButton(.signIn) { request in
          account.configure(request)
        } onCompletion: { result in
          Task {
            busy = true
            defer { busy = false }
            do {
              _ = try await account.signIn(result)
              try await afterSignIn?()
              dismiss()
            } catch let failure as ASAuthorizationError where failure.code == .canceled {
              // Dismissing Apple's sheet is not an error.
            } catch { self.error = error.localizedDescription }
          }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50).disabled(busy)
        if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        Spacer(minLength: 0)
      }
      .padding(24).padding(.top, 32)
      .navigationTitle("Sign in").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.disabled(busy)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

struct FavouritesView: View {
  @Environment(AccountStore.self) private var account
  @Environment(\.dismiss) private var dismiss
  let retailers: [GroceryRetailer]
  let openProduct: (GroceryProduct) -> Void
  @State private var products: [GroceryProduct] = []
  @State private var loadingProducts = false
  @State private var productError: String?
  @State private var showingSignIn = false
  @State private var confirmingDeletion = false
  @State private var showingDeletion = false
  private let service = GroceryService()

  var body: some View {
    NavigationStack {
      Group {
        if !account.isSignedIn {
          ContentUnavailableView {
            Label("Your favourites", systemImage: "heart")
          } description: {
            Text("Sign in to save products and see them on your other devices.")
          } actions: {
            Button("Sign in with Apple") { showingSignIn = true }.buttonStyle(.borderedProminent)
          }
        } else if account.loadingFavourites || loadingProducts {
          ProgressView("Loading favourites…")
        } else if !account.favouritesLoaded {
          ContentUnavailableView {
            Label("Couldn’t load favourites", systemImage: "wifi.exclamationmark")
          } description: {
            Text("Check your connection and try again.")
          } actions: {
            Button("Try again") { Task { await account.refreshFavourites() } }.buttonStyle(
              .bordered)
          }
        } else if let productError {
          ContentUnavailableView {
            Label("Couldn’t load products", systemImage: "wifi.exclamationmark")
          } description: {
            Text(productError)
          } actions: {
            Button("Try again") { Task { await loadProducts() } }.buttonStyle(.bordered)
          }
        } else if account.favouriteIDs.isEmpty {
          ContentUnavailableView(
            "No favourites yet", systemImage: "heart",
            description: Text("Tap the heart on a product to save it here."))
        } else {
          List {
            ForEach(products) { product in
              Button {
                openProduct(product)
                dismiss()
              } label: {
                HStack(spacing: 12) {
                  AsyncImage(url: product.imageURL) { image in
                    image.resizable().scaledToFit()
                  } placeholder: {
                    Image(systemName: "basket").foregroundStyle(.secondary)
                  }.frame(width: 48, height: 48).accessibilityHidden(true)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(
                      .primary)
                    let retailer = GroceryRetailer.displayName(for: product.chain, in: retailers)
                    let details = [retailer, product.packageSize ?? ""].filter { !$0.isEmpty }
                    Text(details.joined(separator: " · "))
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(product.price.map { $0.formatted(.currency(code: "AUD")) } ?? "—").font(
                    .headline)
                }
              }.buttonStyle(.plain)
            }
            if products.count < account.favouriteIDs.count {
              Text("Some saved products are not currently available in the catalogue.").font(
                .caption
              ).foregroundStyle(.secondary)
            }
          }
          .refreshable {
            await account.refreshFavourites()
            await loadProducts()
          }
        }
      }
      .navigationTitle("Favourites")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        if account.isSignedIn {
          ToolbarItem(placement: .topBarTrailing) {
            Menu("Account", systemImage: "person.crop.circle") {
              Button("Refresh favourites", systemImage: "arrow.clockwise") {
                Task {
                  await account.refreshFavourites()
                  await loadProducts()
                }
              }
              Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                Task { await account.signOut() }
              }
              Button("Delete account", systemImage: "trash", role: .destructive) {
                confirmingDeletion = true
              }
            }
          }
        }
      }
      .task(id: account.userID) { if account.isSignedIn { await account.refreshFavourites() } }
      .task(id: account.favouriteIDs) { await loadProducts() }
      .sheet(isPresented: $showingSignIn) { AppleSignInView() }
      .sheet(isPresented: $showingDeletion) { DeleteAccountView() }
      .alert("Delete your account?", isPresented: $confirmingDeletion) {
        Button("Continue", role: .destructive) { showingDeletion = true }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "This permanently deletes your account and saved favourites. You’ll be asked to confirm with Apple."
        )
      }
      .alert(
        "Account",
        isPresented: Binding(
          get: { account.message != nil }, set: { if !$0 { account.message = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(account.message ?? "")
      }
    }
  }

  private func loadProducts() async {
    let ids = account.favouriteIDs
    guard !ids.isEmpty else {
      products = []
      loadingProducts = false
      productError = nil
      return
    }
    loadingProducts = true
    productError = nil
    do {
      let loaded = try await service.products(ids: Array(ids))
      guard !Task.isCancelled, ids == account.favouriteIDs else { return }
      products = loaded
      loadingProducts = false
    } catch {
      guard !Task.isCancelled, ids == account.favouriteIDs else { return }
      productError = "Please check your connection and try again."
      loadingProducts = false
    }
  }
}

private struct DeleteAccountView: View {
  @Environment(AccountStore.self) private var account
  @Environment(\.dismiss) private var dismiss
  @State private var busy = false
  @State private var error: String?
  @State private var revokeIncomplete = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Image(systemName: "person.crop.circle.badge.xmark").font(.system(size: 52)).foregroundStyle(
          .secondary)
        Text("Confirm account deletion").font(.title2.bold())
        Text(
          "Continue with the same Apple Account to permanently delete your account and favourites."
        )
        .multilineTextAlignment(.center).foregroundStyle(.secondary)
        if busy { ProgressView("Deleting account…") }
        SignInWithAppleButton(.continue) { request in
          account.configure(request)
        } onCompletion: { result in
          Task {
            busy = true
            defer { busy = false }
            do {
              if try await account.deleteAccount(result) {
                dismiss()
              } else {
                revokeIncomplete = true
              }
            } catch let failure as ASAuthorizationError where failure.code == .canceled {} catch {
              self.error = "Account deletion could not be completed. Please try again."
            }
          }
        }.signInWithAppleButtonStyle(.black).frame(height: 50).disabled(busy)
        if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        Spacer()
      }.padding(24).padding(.top, 24)
        .alert("Account deleted", isPresented: $revokeIncomplete) {
          Button("Done") { dismiss() }
        } message: {
          Text(
            "Your account and favourites were deleted. Apple sign-in could not be disconnected automatically. In Settings, go to your Apple Account > Sign-In & Security > Sign in with Apple and remove Papa Price Checker."
          )
        }
        .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }.disabled(busy)
          }
        }
    }.presentationDetents([.medium, .large])
  }
}
