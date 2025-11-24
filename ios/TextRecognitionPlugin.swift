//
//  TextRecognitionPlugin.swift
//  react-native-vision-camera-ml-kit
//

import Foundation
import VisionCamera
import MLKitVision
import MLKitCommon
import MLKitTextRecognition
import MLKitTextRecognitionChinese
import MLKitTextRecognitionDevanagari
import MLKitTextRecognitionJapanese
import MLKitTextRecognitionKorean

@objc(TextRecognitionPlugin)
public class TextRecognitionPlugin: FrameProcessorPlugin {

    private var textRecognizer: TextRecognizer!
    private let processingLock = NSLock()
    private var isProcessing = false

    public override init(proxy: VisionCameraProxyHolder, options: [AnyHashable: Any]! = [:]) {
        super.init(proxy: proxy, options: options)

        let language = (options["language"] as? String ?? "latin").lowercased()
        Logger.info("Initializing text recognition with language: \(language)")

        switch language {
        case "chinese":
            textRecognizer = TextRecognizer.textRecognizer(options: ChineseTextRecognizerOptions())
        case "devanagari":
            textRecognizer = TextRecognizer.textRecognizer(options: DevanagariTextRecognizerOptions())
        case "japanese":
            textRecognizer = TextRecognizer.textRecognizer(options: JapaneseTextRecognizerOptions())
        case "korean":
            textRecognizer = TextRecognizer.textRecognizer(options: KoreanTextRecognizerOptions())
        case "latin", "default":
            textRecognizer = TextRecognizer.textRecognizer(options: TextRecognizerOptions())
        default:
            Logger.warn("Unknown language '\(language)', defaulting to Latin")
            textRecognizer = TextRecognizer.textRecognizer(options: TextRecognizerOptions())
        }

        Logger.info("Text recognition initialized successfully")
    }

    deinit {
        // Clean up ML Kit resources when plugin is deallocated
        // Swift ARC will handle the deallocation, but we log for debugging
        Logger.debug("TextRecognitionPlugin deallocating - ML Kit recognizer resources will be freed")
        // Note: ML Kit resources are automatically freed by ARC when textRecognizer is deallocated
    }

    public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable: Any]?) -> Any? {
        // Skip frame if previous processing is still in progress
        processingLock.lock()
        if isProcessing {
            processingLock.unlock()
            Logger.debug("Skipping frame - previous processing still in progress")
            return nil
        }
        isProcessing = true
        processingLock.unlock()

        // Use Vision Camera's reference counting to keep frame alive during processing
        frame.incrementRefCount()

        let startTime = Date()

        defer {
            // Release frame reference and reset processing flag
            frame.decrementRefCount()
            processingLock.lock()
            isProcessing = false
            processingLock.unlock()
        }

        do {
            let orientation = frame.orientation

            let visionImage = VisionImage(buffer: frame.buffer)
            visionImage.orientation = getOrientation(orientation: orientation)

            Logger.debug("Processing frame: \(frame.width)x\(frame.height), orientation: \(orientation.rawValue)")

            // Process synchronously
            let text = try textRecognizer.results(in: visionImage)

            let processingTime = Int64(Date().timeIntervalSince(startTime) * 1000)
            Logger.performance("Text recognition processing", durationMs: processingTime)

            if text.text.isEmpty {
                Logger.debug("No text detected in frame")
                return nil
            }

            Logger.debug("Text detected: \(text.text.count) characters, \(text.blocks.count) blocks")

            return [
                "text": text.text,
                "blocks": processBlocks(text.blocks)
            ]

        } catch {
            let processingTime = Int64(Date().timeIntervalSince(startTime) * 1000)
            Logger.error("Error during text recognition: \(error.localizedDescription)")
            Logger.performance("Text recognition processing (error)", durationMs: processingTime)
            return nil
        }
    }

    // MARK: - Orientation Mapping

    private func getOrientation(orientation: UIImage.Orientation) -> UIImage.Orientation {
        switch orientation {
        case .up:
            return .up
        case .left:
            return .right  // Swap left and right
        case .down:
            return .down
        case .right:
            return .left   // Swap left and right
        default:
            return .up
        }
    }

    // MARK: - Helper Methods

    private func processBlocks(_ blocks: [TextBlock]) -> [[String: Any]] {
        return blocks.map { block in
            var blockDict: [String: Any] = [
                "text": block.text,
                "frame": processRect(block.frame),
                "cornerPoints": processCornerPoints(block.cornerPoints),
                "lines": processLines(block.lines)
            ]

            if let lang = block.recognizedLanguages.first?.languageCode {
                blockDict["recognizedLanguage"] = lang
            }

            return blockDict
        }
    }

    private func processLines(_ lines: [TextLine]) -> [[String: Any]] {
        return lines.map { line in
            var lineDict: [String: Any] = [
                "text": line.text,
                "frame": processRect(line.frame),
                "cornerPoints": processCornerPoints(line.cornerPoints),
                "elements": processElements(line.elements)
            ]

            if let lang = line.recognizedLanguages.first?.languageCode {
                lineDict["recognizedLanguage"] = lang
            }

            return lineDict
        }
    }

    private func processElements(_ elements: [TextElement]) -> [[String: Any]] {
        return elements.map { element in
            var elementDict: [String: Any] = [
                "text": element.text,
                "frame": processRect(element.frame),
                "cornerPoints": processCornerPoints(element.cornerPoints)
            ]

            if let lang = element.recognizedLanguages.first?.languageCode {
                elementDict["recognizedLanguage"] = lang
            }

            return elementDict
        }
    }

    private func processRect(_ rect: CGRect) -> [String: CGFloat] {
        return [
            "x": rect.midX,
            "y": rect.midY,
            "width": rect.width,
            "height": rect.height
        ]
    }

    private func processCornerPoints(_ cornerPoints: [NSValue]) -> [[String: Int]] {
        return cornerPoints.compactMap { $0.cgPointValue }.map { point in
            ["x": Int(point.x), "y": Int(point.y)]
        }
    }
}
