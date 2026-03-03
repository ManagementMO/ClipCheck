import SwiftUI

/// Example: QR code on a trailhead sign. Hiker scans it, sees trail info, taps to check in.
struct TrailCheckInExperience: ClipExperience {
    static let urlPattern = "trails.gov/trail/:trailId"
    static let clipName = "Trail Check-In"
    static let clipDescription = "Scan a trailhead sign to see trail info and log your start."

    let context: ClipContext
    @State private var checkedIn = false

    private var trailName: String {
        switch context.pathParameters["trailId"] {
        case "grouse-grind": return "Grouse Grind"
        case "stawamus": return "Stawamus Chief"
        default: return "Trail #\(context.pathParameters["trailId"] ?? "?")"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.55, blue: 0.25),
                    Color(red: 0.08, green: 0.35, blue: 0.15),
                    Color(red: 0.04, green: 0.20, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(trailName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text("British Columbia, Canada")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
                    .frame(height: 40)

                GlassEffectContainer {
                    HStack(spacing: 0) {
                        StatBadge(value: "5.2", unit: "km", icon: "arrow.left.and.right")
                        StatBadge(value: "850", unit: "m gain", icon: "arrow.up.right")
                        StatBadge(value: "Hard", unit: "", icon: "flame.fill")
                    }
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)

                Spacer()
                    .frame(height: 20)

                HStack(spacing: 20) {
                    Label("12°C", systemImage: "thermometer.medium")
                    Label("Cloudy", systemImage: "cloud.sun.fill")
                    Label("Dry", systemImage: "drop.fill")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

                Spacer()

                if checkedIn {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white)
                        Text("You're checked in. Enjoy your hike!")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.4)) { checkedIn = true }
                    } label: {
                        Text("I'm Starting This Trail")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(red: 0.08, green: 0.35, blue: 0.15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
                    .frame(height: 16)

                ConstraintBanner()
                    .padding(.bottom, 16)
            }
            .safeAreaPadding(.top, 60)
        }
    }
}

private struct StatBadge: View {
    let value: String
    let unit: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
