import SwiftUI

/// Example clip demonstrating ClipExperience protocol conformance.
struct HelloClipExperience: ClipExperience {
    static let urlPattern = "example.com/hello/:name"
    static let clipName = "Hello Clip"
    static let clipDescription = "A minimal example demonstrating ClipExperience protocol conformance."

    let context: ClipContext

    private var name: String {
        context.pathParameters["name"] ?? "World"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)

                    Text("Hello, \(name)!")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                GlassEffectContainer {
                    VStack(spacing: 8) {
                        InfoRow(label: "URL", value: context.invocationURL.absoluteString)

                        ForEach(context.pathParameters.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            InfoRow(label: ":\(key)", value: value)
                        }

                        ForEach(context.queryParameters.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            InfoRow(label: "?\(key)", value: value)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Text("Replace this with your own clip experience.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))

                ConstraintBanner()
                    .padding(.bottom, 16)
            }
            .safeAreaPadding(.top, 60)
        }
    }
}

private struct InfoRow: View {
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
