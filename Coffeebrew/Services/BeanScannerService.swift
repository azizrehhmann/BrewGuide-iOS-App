import Vision
import UIKit

/// Uses Vision framework to perform OCR on a captured coffee bag image.
nonisolated final class BeanScannerService {

    /// Recognize text from a UIImage using Vision's VNRecognizeTextRequest
    @concurrent
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ScanError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ScanError.visionError(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ScanError.noTextFound)
                    return
                }

                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                if lines.isEmpty {
                    continuation.resume(throwing: ScanError.noTextFound)
                } else {
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ScanError.visionError(error.localizedDescription))
            }
        }
    }

    enum ScanError: LocalizedError {
        case invalidImage
        case noTextFound
        case visionError(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Could not process the captured image."
            case .noTextFound:
                return "No text was detected on the bag. Try holding the camera closer to the label."
            case .visionError(let detail):
                return "Vision error: \(detail)"
            }
        }
    }
}
