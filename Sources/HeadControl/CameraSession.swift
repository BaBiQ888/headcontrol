import AVFoundation
import CoreMedia
import Foundation

final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "head-control.camera")
    private let onFrame: (CMSampleBuffer) -> Void

    init(onFrame: @escaping (CMSampleBuffer) -> Void) {
        self.onFrame = onFrame
    }

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        guard let device else { throw SessionError.noCamera }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw SessionError.cannotAddInput }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw SessionError.cannotAddOutput }
        session.addOutput(output)

        // Mirror so x increases as the user moves to their right (more intuitive).
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onFrame(sampleBuffer)
    }

    enum SessionError: Error, CustomStringConvertible {
        case noCamera, cannotAddInput, cannotAddOutput

        var description: String {
            switch self {
            case .noCamera:        return "No camera device found."
            case .cannotAddInput:  return "Cannot add camera input to session."
            case .cannotAddOutput: return "Cannot add video output to session."
            }
        }
    }
}
