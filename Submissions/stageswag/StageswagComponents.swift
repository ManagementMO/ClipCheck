import SwiftUI

// MARK: - Background

struct StageswagBackground: View {
    let theme: StageswagTheme

    var body: some View {
        ZStack {
            Color(.systemBackground)

            LinearGradient(
                colors: [
                    theme.primaryGradient[0].opacity(0.25),
                    theme.primaryGradient[1].opacity(0.15),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    theme.accentColor.opacity(0.12),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Parallax Header

struct StageswagParallaxHeader: View {
    let band: StageswagBand
    let theme: StageswagTheme
    let minY: CGFloat

    private var parallaxOffset: CGFloat { minY > 0 ? -minY * 0.5 : 0 }
    private var stretchScale: CGFloat { minY > 0 ? 1 + minY / 500 : 1 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.primaryGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.white.opacity(0.9))

                Text(band.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text(band.tourName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                    Text(band.venue)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 2)
            }
            .padding(.vertical, 32)
        }
        .frame(height: 220)
        .scaleEffect(stretchScale, anchor: .top)
        .offset(y: parallaxOffset)
        .clipped()
    }
}

// MARK: - Theme Picker

struct StageswagThemePicker: View {
    @Binding var selectedTheme: StageswagTheme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(StageswagTheme.allCases) { theme in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTheme = theme
                    }
                } label: {
                    Circle()
                        .fill(theme.pickerColor)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if theme == selectedTheme {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                            }
                        }
                        .scaleEffect(theme == selectedTheme ? 1.15 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.displayName)
                .accessibilityAddTraits(theme == selectedTheme ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}

// MARK: - Song Row

struct StageswagSongRow: View {
    let song: StageswagSong
    let isUnlocked: Bool
    let secondsUntilUnlock: Int
    let theme: StageswagTheme
    let onTap: () -> Void

    @State private var didUnlock = false

    var body: some View {
        Button(action: {
            if isUnlocked { onTap() }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? song.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
                        .frame(width: 42, height: 42)

                    if isUnlocked {
                        Image(systemName: "music.note")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(song.accentColor)
                            .contentTransition(.symbolEffect(.replace))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(song.trackNumber).")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(song.title)
                            .font(.system(size: 16, weight: isUnlocked ? .semibold : .regular))
                            .foregroundStyle(isUnlocked ? .primary : .tertiary)
                    }

                    if isUnlocked {
                        Text("\(song.merchItems.count) exclusive items")
                            .font(.system(size: 12))
                            .foregroundStyle(song.accentColor.opacity(0.8))
                    } else if secondsUntilUnlock > 0 {
                        StageswagCountdownLabel(seconds: secondsUntilUnlock, theme: theme)
                    }
                }

                Spacer()

                if isUnlocked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(song.accentColor.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if isUnlocked && didUnlock {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(song.accentColor.opacity(0.4), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isUnlocked && didUnlock ? 1.0 : (isUnlocked ? 1.0 : 0.98))
        .opacity(isUnlocked ? 1.0 : 0.6)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: isUnlocked)
        .onChange(of: isUnlocked) { _, newValue in
            if newValue { didUnlock = true }
        }
    }
}

// MARK: - Countdown Label

struct StageswagCountdownLabel: View {
    let seconds: Int
    let theme: StageswagTheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
            Text("Unlocks in \(seconds)s")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(theme.textHighlight.opacity(0.7))
    }
}

// MARK: - Song Merch Card

struct StageswagMerchCard: View {
    let item: StageswagMerchItem
    let theme: StageswagTheme
    let onAdd: (String?) -> Void

    @State private var selectedSize: String? = nil
    private let sizes = ["S", "M", "L", "XL"]

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(item.accentColor.opacity(0.12))
                    .frame(height: 110)

                Image(systemName: item.icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [item.accentColor, item.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(String(format: "$%.2f", item.price))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(item.accentColor)
            }

            if item.isApparel {
                HStack(spacing: 6) {
                    ForEach(sizes, id: \.self) { size in
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedSize = size
                            }
                        } label: {
                            Text(size)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selectedSize == size ? .white : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background {
                                    if selectedSize == size {
                                        Capsule().fill(item.accentColor)
                                    } else {
                                        Capsule().fill(Color(.tertiarySystemFill))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(size)
                        .accessibilityAddTraits(selectedSize == size ? .isSelected : [])
                    }
                }
            }

            Button {
                onAdd(selectedSize)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bag.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(canAdd ? item.accentColor : Color.gray.opacity(0.4), in: Capsule())
            }
            .disabled(!canAdd)
        }
        .padding(12)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18))
    }

    private var canAdd: Bool {
        !item.isApparel || selectedSize != nil
    }
}
