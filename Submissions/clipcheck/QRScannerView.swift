//  QRScannerView.swift
//  ClipCheck — Restaurant Safety Score via App Clip

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onScanned: (String) -> Void
    let onCancel: () -> Void

    @State private var torchOn = false

    var body: some View {
        ZStack {
            #if targetEnvironment(simulator)
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.11, blue: 0.16),
                    Color(red: 0.15, green: 0.22, blue: 0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.white.opacity(0.78))
                Text("Camera not available on Simulator")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Use manual entry or demo cards instead")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            #else
            CameraPreview(torchOn: $torchOn, onScanned: onScanned)
                .ignoresSafeArea()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.32), .clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            #endif

            scannerOverlay

            VStack {
                HStack {
                    controlButton(icon: "xmark", isTorch: false) { onCancel() }

                    Spacer()

                    #if !targetEnvironment(simulator)
                    controlButton(
                        icon: torchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                        isTorch: torchOn
                    ) {
                        torchOn.toggle()
                    }
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 4) {
                    Text("Point camera at a ClipCheck QR code")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Scans automatically when detected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .glassEffect(.regular.interactive(), in: Capsule())
                .padding(.bottom, 40)
            }
        }
    }

    private func controlButton(icon: String, isTorch: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isTorch ? .yellow : .white)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.8)
                }
                .glassEffect(.regular.interactive(), in: Circle())
        }
    }

    // MARK: - Scanner Overlay

    private var scannerOverlay: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.65
            let rect = CGRect(
                x: (geo.size.width - size) / 2,
                y: (geo.size.height - size) / 2 - 30,
                width: size,
                height: size
            )

            // Dark overlay with cutout
            ScannerMask(cutout: rect)
                .fill(.black.opacity(0.56))
                .ignoresSafeArea()

            // Corner brackets
            CornerBrackets(rect: rect)
                .stroke(.white.opacity(0.9), lineWidth: 3)
        }
    }
}

// MARK: - Scanner Mask (dark overlay with clear cutout)

private struct ScannerMask: Shape {
    let cutout: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 12, height: 12))
        return path
    }

    var style: FillStyle { FillStyle(eoFill: true) }

    func fill<S: ShapeStyle>(_ style: S) -> some View {
        _ShapeFillView(shape: self, style: style, fillStyle: FillStyle(eoFill: true))
    }
}

private struct _ShapeFillView<S: Shape, F: ShapeStyle>: View {
    let shape: S
    let style: F
    let fillStyle: FillStyle

    var body: some View {
        shape.fill(style, style: fillStyle)
    }
}

// MARK: - Corner Brackets

private struct CornerBrackets: Shape {
    let rect: CGRect
    private let bracketLen: CGFloat = 24
    private let cornerRadius: CGFloat = 12

    func path(in _: CGRect) -> Path {
        var p = Path()
        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + bracketLen))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + bracketLen, y: rect.minY))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - bracketLen, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bracketLen))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - bracketLen))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - bracketLen, y: rect.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + bracketLen, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - bracketLen))

        return p
    }
}

// MARK: - Camera Preview (physical device only)

#if !targetEnvironment(simulator)
private struct CameraPreview: UIViewControllerRepresentable {
    @Binding var torchOn: Bool
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> CameraScannerController {
        let vc = CameraScannerController()
        vc.onScanned = onScanned
        return vc
    }

    func updateUIViewController(_ vc: CameraScannerController, context: Context) {
        vc.setTorch(torchOn)
    }
}

final class CameraScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
        setTorch(false)
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        MainActor.assumeIsolated {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            hasScanned = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onScanned?(value)
        }
    }
}
#endif
