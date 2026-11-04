import Foundation
import Security

/// Somewhere the favourites are copied to whenever they change (item 36), so a
/// process that cannot open the app's `UserDefaults` — the home-screen widget
/// — can still read them.
///
/// The store calls `publish` after every save and once at start-up, so a
/// mirror that was empty before this build installed is filled on the first
/// launch rather than waiting for the next star.
public protocol FavouritesMirror: Sendable {
    func publish(_ favourites: [FavouriteDestination])
}

/// The favourites as one keychain item, readable by the app *and* its widget
/// extension.
///
/// ## Why the keychain, and why it is a stopgap
///
/// The right home for app-and-extension data is an App Group container. An
/// App Group has to be registered in the developer portal and added to both
/// App IDs, and both distribution profiles regenerated — portal steps the App
/// Store Connect API does not expose, so they wait for a browser session
/// (`docs/testflight-setup-checklist.md`, "App Group"). Keychain sharing needs
/// none of that: every profile on this team already carries
/// `keychain-access-groups = CNHB9B5GX6.*`, so the app and the extension only
/// have to *declare* the same group in their entitlements
/// (`$(AppIdentifierPrefix)dev.thisolivier.timeconverter`, first in both
/// lists, so it is the default group for items written without one).
///
/// When the App Group exists this type becomes a `UserDefaults(suiteName:)`
/// write and read — one file, nothing else moves.
///
/// Not a secret, so no special handling: one generic-password item, readable
/// after the first unlock (a widget may refresh before the user has unlocked
/// since a restart; WidgetKit reloads it afterwards anyway). Unreadable or
/// absent degrades to no favourites, like the store itself.
public struct KeychainFavouritesMirror: FavouritesMirror {
    public static let service = "dev.thisolivier.timeconverter.favourites"
    public static let account = "snapshot"

    public init() {}

    public func publish(_ favourites: [FavouriteDestination]) {
        guard let data = try? JSONEncoder().encode(favourites) else { return }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(Self.itemQuery as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }
        let addQuery = Self.itemQuery.merging(attributes) { _, new in new }
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    public static func read() -> [FavouriteDestination] {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let favourites = try? JSONDecoder().decode([FavouriteDestination].self, from: data)
        else { return [] }
        return favourites
    }

    private static var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
