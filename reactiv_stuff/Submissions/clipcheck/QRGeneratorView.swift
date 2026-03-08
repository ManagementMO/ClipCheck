//  QRGeneratorView.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var saved = false

    private var restaurants: [RestaurantData] {
        RestaurantDataStore.shared.allRestaurants
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("Print these QR codes and place them at restaurant tables for the demo.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Personalized demo QR codes (with allergens/diet in URL)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PERSONALIZED DEMOS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                        ], spacing: 16) {
                            ForEach(personalizedDemos, id: \.url) { demo in
                                personalizedQRCard(demo)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Divider().padding(.horizontal, 20)

                    Text("ALL RESTAURANTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                    ], spacing: 20) {
                        ForEach(restaurants) { restaurant in
                            qrCard(restaurant)
                        }
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(demo.label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Text(demo.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.blue)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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
