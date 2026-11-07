// Owner: jr-3b (wave 2, correction 11). The seam for `https` images. The package never fetches.
public import CoreGraphics
public import Foundation
public import SwiftUI

/// What a remote image provider says about one `https` image.
///
/// - `notAllowed`: the host does not load it (for example remote images are off). The
///   standard Image shows a placeholder with `reason` and no button.
/// - `needsConsent`: the user has not allowed `host` yet. The Image shows one "Allow…"
///   button that calls `requestConsent(for:elementID:)`.
/// - `loading`: the fetch runs. The Image shows its `loading` slot or a static skeleton.
/// - `image`: the decoded image, ideally at the requested pixel size.
/// - `failed`: the fetch failed. The Image shows its `error` slot or a quiet caption.
public enum JRRemoteImageState: Sendable {
    case notAllowed(reason: String?)
    case needsConsent(host: String)
    case loading
    case image(CGImage)
    case failed(String)
}

/// Loads `https` images for the standard Image and Avatar. The host owns the policy
/// (consent, trust list, fetch limits, cache); `JSONRenderRemoteImages` gives one.
///
/// The views call `state(for:pixelSize:elementID:)` while they draw, so it must return at
/// once (start work, then report `.loading`). When a state changes, increase `revision`.
/// Make the provider `@Observable`: the views read `revision` in `body`, and Observation
/// then redraws them.
@MainActor public protocol JRRemoteImageProvider: AnyObject {
    func state(for url: URL, pixelSize: CGSize, elementID: String) -> JRRemoteImageState
    func requestConsent(for url: URL, elementID: String)
    var revision: Int { get }
}

extension EnvironmentValues {
    /// The remote image provider. `nil` (the default): an `https` image is a placeholder.
    @Entry public var jrRemoteImageProvider: (any JRRemoteImageProvider)? = nil
}
