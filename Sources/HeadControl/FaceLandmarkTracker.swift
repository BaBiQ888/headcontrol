import CoreMedia
import Foundation
import Vision

/// Wraps Vision's face-landmark request and emits the nose-tip position
/// in normalized image coordinates (origin bottom-left, range 0...1).
final class FaceLandmarkTracker {
    private let onNose: (Double, Double, TimeInterval) -> Void

    init(onNose: @escaping (Double, Double, TimeInterval) -> Void) {
        self.onNose = onNose
    }

    func process(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
            guard let self,
                  let face = req.results?.first as? VNFaceObservation,
                  let nose = face.landmarks?.nose else { return }

            // `normalizedPoints` here are relative to the face bounding box.
            let pts = nose.normalizedPoints
            guard !pts.isEmpty else { return }

            let cx = pts.reduce(0.0) { $0 + Double($1.x) } / Double(pts.count)
            let cy = pts.reduce(0.0) { $0 + Double($1.y) } / Double(pts.count)

            // Map back to full-image normalized coordinates.
            let bb = face.boundingBox
            let imgX = Double(bb.origin.x) + cx * Double(bb.size.width)
            let imgY = Double(bb.origin.y) + cy * Double(bb.size.height)

            self.onNose(imgX, imgY, timestamp)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}
