import SwiftUI

struct LandingView: View {
    @Bindable var router: ClipRouter

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.08, green: 0.08, blue: 0.22),
                    Color(red: 0.12, green: 0.10, blue: 0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "appclip")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .blue.opacity(0.4), radius: 20)

                    Text("ReactivChallengeKit")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Build an App Clip experience.\nType a URL below to invoke it.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if !ClipRouter.allExperiences.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REGISTERED CLIPS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 4)

                        GlassEffectContainer {
                            VStack(spacing: 8) {
                                ForEach(ClipRouter.allExperiences.indices, id: \.self) { i in
                                    let exp = ClipRouter.allExperiences[i]
                                    let sampleURL = ClipRouter.sampleURL(for: exp.urlPattern)
                                    ClipCard(
                                        name: exp.clipName,
                                        pattern: sampleURL,
                                        description: exp.clipDescription
                                    ) {
                                        router.invoke(urlString: sampleURL)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()
                    .frame(height: 16)

                InvocationConsole(router: router)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct ClipCard: View {
    let name: String
    let pattern: String
    let description: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "appclip")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(pattern)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
