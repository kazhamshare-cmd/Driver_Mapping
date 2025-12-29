import UIKit
import CoreImage
import AVFoundation

class WatermarkRenderer {

    // MARK: - Add Watermark to Image
    static func addWatermark(to image: UIImage, isPro: Bool) -> UIImage {
        guard !isPro else { return image }

        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)

            // Watermark settings
            let watermarkText = "DualMoza"
            let fontSize: CGFloat = min(image.size.width, image.size.height) * 0.08

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.5),
                .strokeColor: UIColor.black.withAlphaComponent(0.3),
                .strokeWidth: -2
            ]

            let textSize = watermarkText.size(withAttributes: attributes)

            // Position: bottom right corner
            let padding: CGFloat = 20
            let textPoint = CGPoint(
                x: image.size.width - textSize.width - padding,
                y: image.size.height - textSize.height - padding
            )

            watermarkText.draw(at: textPoint, withAttributes: attributes)
        }
    }

    // MARK: - Add Watermark to Video Frame (CIImage)
    static func addWatermark(to ciImage: CIImage, isPro: Bool) -> CIImage {
        guard !isPro else { return ciImage }

        let watermarkText = "DualMoza"
        let imageSize = ciImage.extent.size
        let fontSize: CGFloat = min(imageSize.width, imageSize.height) * 0.06

        // Create watermark image
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let watermarkImage = renderer.image { context in
            // Clear background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))

            // Draw watermark text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .strokeColor: UIColor.black.withAlphaComponent(0.4),
                .strokeWidth: -2
            ]

            let textSize = watermarkText.size(withAttributes: attributes)
            let padding: CGFloat = 30
            let textPoint = CGPoint(
                x: imageSize.width - textSize.width - padding,
                y: padding // Note: UIKit coordinate system (top-left origin)
            )

            watermarkText.draw(at: textPoint, withAttributes: attributes)
        }

        // Convert to CIImage and composite
        guard let watermarkCIImage = CIImage(image: watermarkImage) else {
            return ciImage
        }

        // Flip watermark to match CIImage coordinate system
        let transform = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -imageSize.height)
        let flippedWatermark = watermarkCIImage.transformed(by: transform)

        return flippedWatermark.composited(over: ciImage)
    }

    // MARK: - Create Watermark Overlay for AVVideoComposition
    static func createWatermarkLayer(for videoSize: CGSize) -> CALayer {
        let watermarkLayer = CATextLayer()
        watermarkLayer.string = "DualMoza"
        watermarkLayer.font = UIFont.systemFont(ofSize: 1, weight: .bold) // Size will be set below
        watermarkLayer.fontSize = min(videoSize.width, videoSize.height) * 0.06
        watermarkLayer.foregroundColor = UIColor.white.withAlphaComponent(0.6).cgColor
        watermarkLayer.alignmentMode = .right
        watermarkLayer.contentsScale = UIScreen.main.scale

        let textSize = watermarkLayer.preferredFrameSize()
        let padding: CGFloat = 30
        watermarkLayer.frame = CGRect(
            x: videoSize.width - textSize.width - padding,
            y: padding,
            width: textSize.width,
            height: textSize.height
        )

        // Add shadow for better visibility
        watermarkLayer.shadowColor = UIColor.black.cgColor
        watermarkLayer.shadowOffset = CGSize(width: 1, height: 1)
        watermarkLayer.shadowOpacity = 0.5
        watermarkLayer.shadowRadius = 2

        return watermarkLayer
    }
}
