#if os(iOS)
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct MyProfileQRCodeSheetView: View {
    let profile: FestivalProfileStore

    @Environment(\.dismiss) private var dismiss

    @State private var inviteURL: URL?
    @State private var errorMessage: String?
    @State private var reloadToken = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let inviteURL {
                        QRCodeImageCard(url: inviteURL)
                        Text("friends.qr.my.description")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("friends.qr.generate_new_code") {
                            reloadToken = UUID()
                        }
                    } else if let errorMessage {
                        ContentUnavailableView(
                            "friends.qr.unavailable.title",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                        Button("friends.try_again") {
                            reloadToken = UUID()
                        }
                    } else {
                        ProgressView("friends.qr.preparing_invite")
                            .frame(maxWidth: .infinity, minHeight: 280)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .navigationTitle("friends.qr.my.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("friends.done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: reloadToken) {
            await loadInviteURL()
        }
    }

    private func loadInviteURL() async {
        inviteURL = nil
        errorMessage = nil

        do {
            inviteURL = try await profile.prepareOneTimeShareURL()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FriendProfileQRScannerSheetView: View {
    let profile: FestivalProfileStore

    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @State private var isProcessingScan = false
    @State private var errorMessage: String?
    @State private var scannerResetToken = UUID()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch authorizationStatus {
                case .authorized:
                    ZStack {
                        QRCodeScannerView(
                            onCodeDetected: handleScannedCode(_:),
                            onFailure: handleScannerFailure(_:)
                        )
                        .id(scannerResetToken)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 360)

                        if isProcessingScan {
                            Color.black.opacity(0.45)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            ProgressView("friends.scanner.adding_profile")
                                .tint(.white)
                                .foregroundStyle(.white)
                        }
                    }

                    Text("friends.scanner.instructions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                case .notDetermined:
                    ProgressView("friends.scanner.requesting_camera")
                        .frame(maxWidth: .infinity, minHeight: 320)

                case .denied, .restricted:
                    ContentUnavailableView(
                        "friends.scanner.camera_access_needed.title",
                        systemImage: "camera.fill",
                        description: Text("friends.scanner.camera_access_needed.description")
                    )

                    Button("friends.open_settings") {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        UIApplication.shared.open(settingsURL)
                    }

                @unknown default:
                    ContentUnavailableView(
                        "friends.scanner.unavailable.title",
                        systemImage: "camera.metering.unknown",
                        description: Text("friends.scanner.unavailable.description")
                    )
                }
            }
            .padding(24)
            .navigationTitle("friends.scanner.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("friends.done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await requestCameraAccessIfNeeded()
        }
        .alert("friends.scanner.scan_failed.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                    restartScanner()
                }
            }
        )) {
            Button("friends.try_again", role: .cancel) {
                errorMessage = nil
                restartScanner()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func requestCameraAccessIfNeeded() async {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized, .denied, .restricted:
            break
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            authorizationStatus = granted ? .authorized : .denied
        @unknown default:
            break
        }
    }

    private func handleScannedCode(_ scannedValue: String) {
        guard !isProcessingScan else {
            return
        }

        guard let inviteURL = normalizedInviteURL(from: scannedValue) else {
            errorMessage = friendsLocalizedString("friends.scanner.invalid_invite")
            return
        }

        isProcessingScan = true
        Task {
            do {
                try await profile.acceptShare(url: inviteURL)
                dismiss()
            } catch {
                isProcessingScan = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleScannerFailure(_ message: String) {
        guard errorMessage == nil else {
            return
        }
        errorMessage = message
    }

    private func restartScanner() {
        isProcessingScan = false
        scannerResetToken = UUID()
    }

    private func normalizedInviteURL(from scannedValue: String) -> URL? {
        let trimmedValue = scannedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let inviteURL = URL(string: trimmedValue), inviteURL.scheme != nil else {
            return nil
        }
        return inviteURL
    }
}

private struct QRCodeImageCard: View {
    let url: URL

    private var qrCodeImage: UIImage? {
        QRCodeRenderer.image(for: url)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            } else {
                ContentUnavailableView(
                    "friends.qr.unavailable.title",
                    systemImage: "qrcode",
                    description: Text("friends.qr.render_failed")
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum QRCodeRenderer {
    private static let context = CIContext()

    static func image(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: 14, y: 14))
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeDetected: (String) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        QRCodeScannerViewController(
            onCodeDetected: onCodeDetected,
            onFailure: onFailure
        )
    }

    func updateUIViewController(
        _ uiViewController: QRCodeScannerViewController,
        context: Context
    ) {}
}

private final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "festival-profile-qr-scanner")
    private let onCodeDetected: (String) -> Void
    private let onFailure: (String) -> Void

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDeliveredCode = false
    private var didFinishConfiguration = false

    init(
        onCodeDetected: @escaping (String) -> Void,
        onFailure: @escaping (String) -> Void
    ) {
        self.onCodeDetected = onCodeDetected
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCaptureSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDeliveredCode else {
            return
        }

        guard
            let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let scannedValue = metadataObject.stringValue
        else {
            return
        }

        hasDeliveredCode = true
        stopCaptureSession()
        onCodeDetected(scannedValue)
    }

    private func configureCaptureSession() {
        sessionQueue.async {
            guard let camera = AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    self.onFailure(friendsLocalizedString("friends.scanner.error.no_camera"))
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                let output = AVCaptureMetadataOutput()

                self.captureSession.beginConfiguration()

                guard self.captureSession.canAddInput(input) else {
                    self.captureSession.commitConfiguration()
                    DispatchQueue.main.async {
                        self.onFailure(friendsLocalizedString("friends.scanner.error.camera_connection"))
                    }
                    return
                }
                self.captureSession.addInput(input)

                guard self.captureSession.canAddOutput(output) else {
                    self.captureSession.commitConfiguration()
                    DispatchQueue.main.async {
                        self.onFailure(friendsLocalizedString("friends.scanner.error.start_failed"))
                    }
                    return
                }
                self.captureSession.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]

                self.captureSession.commitConfiguration()
                self.didFinishConfiguration = true

                DispatchQueue.main.async {
                    let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                    previewLayer.videoGravity = .resizeAspectFill
                    previewLayer.frame = self.view.bounds
                    self.view.layer.addSublayer(previewLayer)
                    self.previewLayer = previewLayer
                }
                self.startCaptureSession()
            } catch {
                DispatchQueue.main.async {
                    self.onFailure(error.localizedDescription)
                }
            }
        }
    }

    private func startCaptureSession() {
        sessionQueue.async {
            guard self.didFinishConfiguration, !self.captureSession.isRunning else {
                return
            }
            self.captureSession.startRunning()
        }
    }

    private func stopCaptureSession() {
        sessionQueue.async {
            guard self.captureSession.isRunning else {
                return
            }
            self.captureSession.stopRunning()
        }
    }
}
#endif
