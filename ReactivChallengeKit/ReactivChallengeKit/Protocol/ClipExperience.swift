import SwiftUI

/// Conform to this protocol to create your App Clip experience.
protocol ClipExperience: View {
    /// URL pattern this clip responds to. Use `:paramName` for path parameters.
    static var urlPattern: String { get }

    /// Human-readable name for this clip.
    static var clipName: String { get }

    /// One-line description of what this clip does.
    static var clipDescription: String { get }

    /// Initialize with the parsed invocation context.
    init(context: ClipContext)
}
