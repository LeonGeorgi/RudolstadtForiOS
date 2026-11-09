#if os(iOS)
import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins
import UIKit

struct QRCodeImageCard: View {
    let value: String

    init(url: URL) { value = url.absoluteString }
    init(value: String) { self.value = value }

    private var qrCodeImage: UIImage? {
        QRCodeRenderer.image(for: value)
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

    static func image(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
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

struct QRCodeScannerView: UIViewControllerRepresentable {
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

final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
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
