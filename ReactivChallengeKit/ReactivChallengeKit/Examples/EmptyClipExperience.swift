import SwiftUI

// TODO: Rename this struct to match your clip idea
// TODO: Update urlPattern, clipName, clipDescription
// TODO: Build your UI in body
// TODO: Register this type in ClipRouter.allExperiences

struct EmptyClipExperience: ClipExperience {
    static let urlPattern = "yourapp.com/your-path/:param"
    static let clipName = "Your Clip Name"
    static let clipDescription = "A one-line description of your clip experience."

    let context: ClipContext

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.4), Color.indigo.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Your Clip Experience")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Start building here.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                GlassEffectContainer {
                    VStack(spacing: 8) {
                        InfoPlaceholder(label: "URL", value: context.invocationURL.absoluteString)
                        InfoPlaceholder(label: "param", value: context.pathParameters["param"] ?? "—")
                    }
                }
                .padding(.horizontal, 20)

                ConstraintBanner()
                    .padding(.bottom, 16)
            }
            .safeAreaPadding(.top, 60)
        }
    }
}

private struct InfoPlaceholder: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}
