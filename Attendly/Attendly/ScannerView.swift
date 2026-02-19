import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
    var onCodeFound: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeFound: onCodeFound)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCodeFound: (String) -> Void
        private var hasEmitted = false

        init(onCodeFound: @escaping (String) -> Void) {
            self.onCodeFound = onCodeFound
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !hasEmitted,
                  let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
                  let value = object.stringValue else { return }
            hasEmitted = true
            onCodeFound(value)
        }
    }
}

final class ScannerViewController: UIViewController {
    fileprivate var delegate: (AVCaptureMetadataOutputObjectsDelegate & NSObject)?
    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let unavailableLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Camera unavailable"
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            showUnavailable()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
                output.metadataObjectTypes = [.qr]
            }

            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)

            session.startRunning()
        } catch {
            showUnavailable()
        }
    }

    private func showUnavailable() {
        unavailableLabel.frame = view.bounds
        unavailableLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(unavailableLabel)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }
}
