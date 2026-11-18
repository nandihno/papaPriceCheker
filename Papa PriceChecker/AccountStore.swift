import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security
import Supabase

private struct FavouriteRow: Codable {
  let userID: UUID
  let productID: UUID

  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case productID = "product_id"
  }
}

private struct FavouriteID: Decodable {
  let productID: UUID
  enum CodingKeys: String, CodingKey { case productID = "product_id" }
}

private struct DeletionRequest: Encodable {
  let authorizationCode: String?
  let identityToken: String
  let nonce: String
  enum CodingKeys: String, CodingKey {
    case authorizationCode = "authorization_code"
    case identityToken = "identity_token"
    case nonce
  }
}

private nonisolated struct DeletionResponse: Decodable {
  let appleRevoked: Bool
  enum CodingKeys: String, CodingKey { case appleRevoked = "apple_revoked" }
}

enum AccountError: LocalizedError {
  case nonceUnavailable, missingCredential, differentAccount, signedOut, favouritesUnavailable
  var errorDescription: String? {
    switch self {
    case .nonceUnavailable: "Could not start secure Apple sign-in. Please try again."
    case .missingCredential:
      "Apple did not return the information needed to continue. Please try again."
    case .differentAccount:
      "This Apple Account is different from the account you were using. Please sign in again."
    case .signedOut: "Please sign in to continue."
    case .favouritesUnavailable: "Your favourites could not be loaded. Please try again."
    }
  }
}

@MainActor @Observable
final class AccountStore {
  private let client = SupabaseClient(
    supabaseURL: GroceryConfiguration.url,
    supabaseKey: GroceryConfiguration.publishableKey
  )
  private var nonce: String?
  private var favouritesTask: Task<Void, Never>?
  private var favouritesGeneration = UUID()
  private(set) var userID: UUID?
  private(set) var favouriteIDs: Set<UUID> = []
  private(set) var favouritesLoaded = false
  private(set) var loadingFavourites = false
  private(set) var busyIDs: Set<UUID> = []
  var message: String?

  var isSignedIn: Bool { userID != nil }

  /// The SDK restores and refreshes sessions using secure platform storage.
  func observeSession() async {
    for await (_, session) in client.auth.authStateChanges {
      guard !Task.isCancelled else { return }
      let nextID = session?.user.id
      guard nextID != userID else { continue }
      favouritesTask?.cancel()
      favouritesTask = nil
      favouritesGeneration = UUID()
      userID = nextID
      favouriteIDs = []
      favouritesLoaded = false
      loadingFavourites = false
      busyIDs = []
      if let session {
        // Apple's provider ID is the stable subject returned for this app/team.
        if let appleID = session.user.identities?.first(where: { $0.provider == "apple" })?.id {
          do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(
              forUserID: appleID)
            if state == .revoked || state == .notFound {
              try? await client.auth.signOut(scope: .local)
              if userID == nextID {
                userID = nil
                favouriteIDs = []
              }
              continue
            }
          } catch {
            // An unavailable credential check must not erase a valid session offline.
          }
        }
        await refreshFavourites()
      }
    }
  }

  func configure(_ request: ASAuthorizationAppleIDRequest) {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      nonce = nil
      return
    }
    let value = bytes.map { String(format: "%02x", $0) }.joined()
    nonce = value
    request.nonce = SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    // Names and email are not needed to save products.
    request.requestedScopes = []
  }

  @discardableResult
  func signIn(_ result: Result<ASAuthorization, Error>) async throws -> UUID {
    let authorization = try result.get()
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
      let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8)
    else { throw AccountError.missingCredential }
    guard let nonce else { throw AccountError.nonceUnavailable }
    self.nonce = nil
    let session = try await client.auth.signInWithIdToken(
      credentials: .init(provider: .apple, idToken: token, nonce: nonce))
    if userID != session.user.id {
      favouritesTask?.cancel()
      favouritesTask = nil
      favouritesGeneration = UUID()
      userID = session.user.id
      favouriteIDs = []
      favouritesLoaded = false
      loadingFavourites = false
    }
    await refreshFavourites()
    return session.user.id
  }

  func refreshFavourites() async {
    guard let requestedUser = userID else { return }
    if let favouritesTask {
      await favouritesTask.value
      return
    }
    let generation = favouritesGeneration
    loadingFavourites = true
    let task = Task { await loadFavourites(user: requestedUser, generation: generation) }
    favouritesTask = task
    await task.value
    if generation == favouritesGeneration {
      favouritesTask = nil
      loadingFavourites = false
    }
  }

  private func loadFavourites(user requestedUser: UUID, generation: UUID) async {
    do {
      var ids = Set<UUID>()
      let pageSize = 500
      var offset = 0
      while true {
        let rows: [FavouriteID] = try await client.from("user_favourites")
          .select("product_id")
          .eq("user_id", value: requestedUser.uuidString)
          .order("product_id")
          .range(from: offset, to: offset + pageSize - 1)
          .execute().value
        ids.formUnion(rows.map(\.productID))
        offset += rows.count
        if rows.count < pageSize { break }
      }
      guard requestedUser == userID, generation == favouritesGeneration, !Task.isCancelled else {
        return
      }
      favouriteIDs = ids
      favouritesLoaded = true
    } catch {
      guard requestedUser == userID, generation == favouritesGeneration, !Task.isCancelled else {
        return
      }
      favouritesLoaded = false
      message = "Couldn’t load favourites. Check your connection and try again."
    }
  }

  func toggleFavourite(_ productID: UUID) async throws {
    guard let requestedUser = userID else { throw AccountError.signedOut }
    guard favouritesLoaded, !loadingFavourites else { throw AccountError.favouritesUnavailable }
    guard busyIDs.insert(productID).inserted else { return }
    defer { busyIDs.remove(productID) }
    let removing = favouriteIDs.contains(productID)
    if removing {
      try await client.from("user_favourites").delete()
        .eq("user_id", value: requestedUser.uuidString)
        .eq("product_id", value: productID.uuidString).execute()
    } else {
      try await client.from("user_favourites").upsert(
        FavouriteRow(userID: requestedUser, productID: productID),
        onConflict: "user_id,product_id", returning: .minimal, ignoreDuplicates: true
      ).execute()
    }
    guard requestedUser == userID else { return }
    if removing { favouriteIDs.remove(productID) } else { favouriteIDs.insert(productID) }
  }

  func signOut() async {
    do {
      try await client.auth.signOut(scope: .local)
    } catch {
      // The SDK removes the local session before attempting server revocation.
      message = "Signed out on this device, but the server could not confirm sign-out."
    }
    favouritesTask?.cancel()
    favouritesTask = nil
    favouritesGeneration = UUID()
    userID = nil
    favouriteIDs = []
    favouritesLoaded = false
    loadingFavourites = false
  }

  /// Deletion requires a fresh Apple authorization and a matching Supabase account.
  func deleteAccount(_ result: Result<ASAuthorization, Error>) async throws -> Bool {
    guard let originalUser = userID else { throw AccountError.signedOut }
    let authorization = try result.get()
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
      let tokenData = credential.identityToken,
      let token = String(data: tokenData, encoding: .utf8), let nonce
    else { throw AccountError.missingCredential }
    guard
      let expectedAppleID = client.auth.currentUser?.identities?.first(where: {
        $0.provider == "apple"
      })?.id,
      credential.user == expectedAppleID
    else { throw AccountError.differentAccount }
    let verifiedUser = try await signIn(.success(authorization))
    guard verifiedUser == originalUser else {
      try? await client.auth.signOut(scope: .local)
      throw AccountError.differentAccount
    }
    let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
    let response: DeletionResponse = try await client.functions.invoke(
      "delete-account",
      options: .init(
        body: DeletionRequest(
          authorizationCode: code, identityToken: token, nonce: nonce)))
    try? await client.auth.signOut(scope: .local)
    userID = nil
    favouriteIDs = []
    favouritesLoaded = false
    return response.appleRevoked
  }
}
