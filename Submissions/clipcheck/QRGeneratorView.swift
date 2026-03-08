//  QRGeneratorView.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import SwiftUI
import CoreImage.CIFilterBuiltins

private enum QRTheme {
    static let accent = Color(red: 0.188, green: 0.384, blue: 0.949)
}

struct QRGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var saved = false

    private var restaurants: [RestaurantData] {
        RestaurantDataStore.shared.allRestaurants
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.97, blue: 1.0), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ClipCheck QR Toolkit")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Print these codes and place them at restaurant tables for quick demo invocations.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        VStack(alignment: .leading, spacing: 10) {
                            Label("PERSONALIZED DEMOS", systemImage: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.9)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16),
                            ], spacing: 16) {
                                ForEach(personalizedDemos, id: \.url) { demo in
                                    personalizedQRCard(demo)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                        VStack(alignment: .leading, spacing: 10) {
                            Label("ALL RESTAURANTS", systemImage: "building.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.9)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16),
                            ], spacing: 20) {
                                ForEach(restaurants) { restaurant in
                                    qrCard(restaurant)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("QR Codes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAllToPhotos()
                    } label: {
                        if saving {
                            ProgressView().controlSize(.small)
                        } else if saved {
                            Label("Saved", systemImage: "checkmark")
                        } else {
                            Label("Save All", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(saving || saved)
                }
            }
        }
    }

    // MARK: - Personalized Demo Data

    private struct PersonalizedDemo {
        let url: String
        let label: String
        let subtitle: String
    }

    private var personalizedDemos: [PersonalizedDemo] {
        guard let first = restaurants.first else { return [] }
        return [
            PersonalizedDemo(
                url: "https://example.com/restaurant/\(first.id)/check?allergens=nuts,dairy&diet=vegetarian",
                label: "\(first.name)",
                subtitle: "Nut + Dairy allergy, Vegetarian"
            ),
            PersonalizedDemo(
                url: "https://example.com/restaurant/\(first.id)/check?allergens=gluten",
                label: "\(first.name)",
                subtitle: "Gluten allergy"
            ),
        ]
    }

    private func personalizedQRCard(_ demo: PersonalizedDemo) -> some View {
        VStack(spacing: 8) {
            if let image = generateQRImage(from: demo.url, size: 200) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(demo.label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Text(demo.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(QRTheme.accent)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.8)
        }
    }

    // MARK: - QR Card

    private func qrCard(_ restaurant: RestaurantData) -> some View {
        let url = "https://example.com/restaurant/\(restaurant.id)/check"

        return VStack(spacing: 8) {
            if let image = generateQRImage(from: url, size: 200) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(restaurant.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            HStack(spacing: 4) {
                Circle()
                    .fill(restaurant.trustLevel.color)
                    .frame(width: 6, height: 6)
                Text("\(restaurant.trustScore)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(restaurant.trustLevel.color)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.8)
        }
    }

    // MARK: - QR Generation

    private func generateQRImage(from string: String, size: CGFloat) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        let scale = size / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Save to Photos

    private func saveAllToPhotos() {
        saving = true

        DispatchQueue.global(qos: .userInitiated).async {
            for restaurant in restaurants {
                let url = "https://example.com/restaurant/\(restaurant.id)/check"
                if let image = generateQRImage(from: url, size: 600) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                saving = false
                saved = true
            }
        }
    }
}
