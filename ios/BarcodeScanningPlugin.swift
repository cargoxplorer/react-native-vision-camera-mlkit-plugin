//
//  BarcodeScanningPlugin.swift
//  react-native-vision-camera-ml-kit
//

import Foundation
import VisionCamera
import MLKitVision
import MLKitCommon
import MLKitBarcodeScanning
import CoreImage
import CoreMedia

@objc(BarcodeScanningPlugin)
public class BarcodeScanningPlugin: FrameProcessorPlugin {

    private var scanner: BarcodeScanner!
    private let processingLock = NSLock()
    private var isProcessing = false
    private var detectInvertedBarcodes: Bool = false
    private var tryRotations: Bool = true
    
    // Reusable CIContext for image processing (expensive to create)
    private lazy var ciContext: CIContext = {
        return CIContext(options: [.useSoftwareRenderer: false])
    }()

    public override init(proxy: VisionCameraProxyHolder, options: [AnyHashable: Any]! = [:]) {
        super.init(proxy: proxy, options: options)

        Logger.info("Initializing barcode scanner")

        // Extract options
        detectInvertedBarcodes = options["detectInvertedBarcodes"] as? Bool ?? false
        if detectInvertedBarcodes {
            Logger.warn("⚠️ Inverted barcode detection ENABLED - adds processing time per frame when no barcodes found. Only enable if you specifically need white-on-black barcodes.")
        }

        tryRotations = options["tryRotations"] as? Bool ?? true
        if !tryRotations {
            Logger.info("90 degree rotation attempts DISABLED - only using current camera rotation")
        }

        // Parse formats
        let formats = options["formats"] as? [String]
        let scannerOptions = createScannerOptions(formats: formats)

        scanner = BarcodeScanner.barcodeScanner(options: scannerOptions)
        Logger.info("Barcode scanner initialized successfully")
    }

    deinit {
        // Clean up ML Kit resources when plugin is deallocated
        // Swift ARC will handle the deallocation, but we log for debugging
        Logger.debug("BarcodeScanningPlugin deallocating - ML Kit scanner resources will be freed")
        // Note: ML Kit resources are automatically freed by ARC when scanner is deallocated
    }

    private func createScannerOptions(formats: [String]?) -> BarcodeScannerOptions {
        guard let formats = formats, !formats.isEmpty else {
            Logger.info("No format filter specified, scanning all barcode formats")
            return BarcodeScannerOptions(formats: .all)
        }

        Logger.debug("Parsing \(formats.count) barcode format(s) from options")

        var combinedFormats: BarcodeFormat = []
        for formatString in formats {
            if let parsedFormat = parseBarcodeFormat(formatString) {
                combinedFormats.insert(parsedFormat)
                Logger.debug("Successfully parsed format: '\(formatString)'")
            } else {
                Logger.error("FAILED to parse barcode format: '\(formatString)'")
            }
        }

        if combinedFormats.isEmpty {
            Logger.error("No valid barcode formats could be parsed! Falling back to all formats")
            return BarcodeScannerOptions(formats: .all)
        }

        Logger.info("Scanning barcode format(s) with combined mask")
        return BarcodeScannerOptions(formats: combinedFormats)
    }

    public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable: Any]?) -> Any? {
        // Skip frame if previous processing is still in progress
        processingLock.lock()
        if isProcessing {
            processingLock.unlock()
            if Logger.isDebugEnabled() {
                Logger.debug("Skipping frame - previous processing still in progress")
            }
            return nil
        }
        isProcessing = true
        processingLock.unlock()

        let startTime = Date()

        defer {
            // Reset processing flag
            processingLock.lock()
            isProcessing = false
            processingLock.unlock()
        }

        do {
            let orientation = frame.orientation
            let baseOrientation = getOrientation(orientation: orientation)

            if Logger.isDebugEnabled() {
                Logger.debug("Processing frame: \(frame.width)x\(frame.height), orientation: \(orientation.rawValue)")
            }

            // Build list of orientations to try
            let orientations: [UIImage.Orientation] = tryRotations
                ? [baseOrientation, rotateOrientation90(baseOrientation)]
                : [baseOrientation]

            var barcodes: [Barcode] = []

            // 1. Try normal image at current orientation
            let visionImage = VisionImage(buffer: frame.buffer)
            visionImage.orientation = orientations[0]
            barcodes = try scanner.results(in: visionImage)

            if !barcodes.isEmpty {
                if Logger.isDebugEnabled() {
                    Logger.debug("Found \(barcodes.count) barcode(s) at orientation \(orientations[0].rawValue)")
                }
            } else if tryRotations && orientations.count > 1 {
                // 2. Try normal image at 90 degree rotation
                if Logger.isDebugEnabled() {
                    Logger.debug("No barcodes at orientation \(orientations[0].rawValue), trying \(orientations[1].rawValue)")
                }
                visionImage.orientation = orientations[1]
                barcodes = try scanner.results(in: visionImage)

                if !barcodes.isEmpty && Logger.isDebugEnabled() {
                    Logger.debug("Found \(barcodes.count) barcode(s) at orientation \(orientations[1].rawValue)")
                }
            }

            // 3. If no barcodes found and inverted detection is enabled, try inverted images
            if barcodes.isEmpty && detectInvertedBarcodes {
                if Logger.isDebugEnabled() {
                    Logger.debug("No barcodes in normal image, attempting inverted image scan...")
                }

                let invertStartTime = Date()

                if let invertedImage = createInvertedImage(from: frame.buffer) {
                    // Try inverted at current orientation
                    let invertedVisionImage = VisionImage(image: invertedImage)
                    invertedVisionImage.orientation = orientations[0]
                    barcodes = try scanner.results(in: invertedVisionImage)

                    if !barcodes.isEmpty {
                        if Logger.isDebugEnabled() {
                            Logger.debug("Found \(barcodes.count) barcode(s) in inverted image at orientation \(orientations[0].rawValue)")
                        }
                    } else if tryRotations && orientations.count > 1 {
                        // Try inverted at 90 degree rotation
                        if Logger.isDebugEnabled() {
                            Logger.debug("No barcodes in inverted at \(orientations[0].rawValue), trying \(orientations[1].rawValue)")
                        }
                        invertedVisionImage.orientation = orientations[1]
                        barcodes = try scanner.results(in: invertedVisionImage)

                        if !barcodes.isEmpty && Logger.isDebugEnabled() {
                            Logger.debug("Found \(barcodes.count) barcode(s) in inverted image at orientation \(orientations[1].rawValue)")
                        }
                    }
                }

                let invertTime = Int64(Date().timeIntervalSince(invertStartTime) * 1000)
                Logger.performance("Inverted image scan", durationMs: invertTime)
            }

            let processingTime = Int64(Date().timeIntervalSince(startTime) * 1000)
            Logger.performance("Barcode scanning processing", durationMs: processingTime)

            if barcodes.isEmpty {
                if Logger.isDebugEnabled() {
                    Logger.debug("No barcodes detected in frame (tried all orientations)")
                }
                return nil
            }

            if Logger.isDebugEnabled() {
                Logger.debug("Barcodes detected: \(barcodes.count) barcode(s)")
            }

            let result: [String: Any] = ["barcodes": processBarcodes(barcodes)]
            return result

        } catch {
            let processingTime = Int64(Date().timeIntervalSince(startTime) * 1000)
            Logger.error("Exception during barcode scanning: \(error.localizedDescription)")
            Logger.performance("Barcode scanning processing (error)", durationMs: processingTime)
            return nil
        }
    }
    
    // MARK: - Image Processing
    
    /// Rotate orientation by 90 degrees clockwise
    private func rotateOrientation90(_ orientation: UIImage.Orientation) -> UIImage.Orientation {
        switch orientation {
        case .up: return .right
        case .right: return .down
        case .down: return .left
        case .left: return .up
        case .upMirrored: return .rightMirrored
        case .rightMirrored: return .downMirrored
        case .downMirrored: return .leftMirrored
        case .leftMirrored: return .upMirrored
        @unknown default: return .right
        }
    }
    
    /// Create an inverted (negative) version of the image for detecting white-on-black barcodes
    private func createInvertedImage(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            Logger.error("Failed to get pixel buffer from sample buffer")
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply color invert filter
        guard let invertFilter = CIFilter(name: "CIColorInvert") else {
            Logger.error("Failed to create CIColorInvert filter")
            return nil
        }
        invertFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = invertFilter.outputImage else {
            Logger.error("Failed to get output from invert filter")
            return nil
        }
        
        // Convert to CGImage then UIImage
        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            Logger.error("Failed to create CGImage from CIImage")
            return nil
        }
        
        return UIImage(cgImage: cgImage)
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

    // MARK: - Format Parsing

    private func parseBarcodeFormat(_ format: String) -> BarcodeFormat? {
        switch format.lowercased() {
        case "codabar": return .codaBar
        case "code39": return .code39
        case "code93": return .code93
        case "code128": return .code128
        case "ean8": return .EAN8
        case "ean13": return .EAN13
        case "itf": return .ITF
        case "upca": return .UPCA
        case "upce": return .UPCE
        case "aztec": return .aztec
        case "datamatrix": return .dataMatrix
        case "pdf417": return .PDF417
        case "qrcode": return .qrCode
        default:
            Logger.warn("Unknown barcode format: \(format)")
            return nil
        }
    }

    private func barcodeFormatToString(_ format: BarcodeFormat) -> String {
        switch format {
        case .codaBar: return "codabar"
        case .code39: return "code39"
        case .code93: return "code93"
        case .code128: return "code128"
        case .EAN8: return "ean8"
        case .EAN13: return "ean13"
        case .ITF: return "itf"
        case .UPCA: return "upca"
        case .UPCE: return "upce"
        case .aztec: return "aztec"
        case .dataMatrix: return "datamatrix"
        case .PDF417: return "pdf417"
        case .qrCode: return "qrcode"
        default: return "unknown"
        }
    }

    private func valueTypeToString(_ valueType: BarcodeValueType) -> String {
        switch valueType {
        case .text: return "text"
        case .URL: return "url"
        case .email: return "email"
        case .phone: return "phone"
        case .SMS: return "sms"
        case .wiFi: return "wifi"
        case .geographicCoordinates: return "geo"
        case .contactInfo: return "contact"
        case .calendarEvent: return "calendarEvent"
        case .driversLicense: return "driverLicense"
        default: return "unknown"
        }
    }

    // MARK: - Barcode Processing

    private func processBarcodes(_ barcodes: [Barcode]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for barcode in barcodes {
            let processed = processBarcode(barcode)
            result.append(processed)
        }
        return result
    }

    private func processBarcode(_ barcode: Barcode) -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["rawValue"] = barcode.rawValue ?? ""
        dict["displayValue"] = barcode.displayValue ?? ""
        dict["format"] = barcodeFormatToString(barcode.format)
        dict["valueType"] = valueTypeToString(barcode.valueType)
        dict["frame"] = processRect(barcode.frame)
        dict["cornerPoints"] = processCornerPoints(barcode.cornerPoints)

        addStructuredData(to: &dict, barcode: barcode)

        return dict
    }

    private func addStructuredData(to dict: inout [String: Any], barcode: Barcode) {
        switch barcode.valueType {
        case .wiFi:
            if let wifi = barcode.wifi {
                dict["wifi"] = processWifi(wifi)
            }
        case .URL:
            if let url = barcode.url?.url {
                dict["url"] = url
            }
        case .email:
            if let email = barcode.email?.address {
                dict["email"] = email
            }
        case .phone:
            if let phone = barcode.phone?.number {
                dict["phone"] = phone
            }
        case .SMS:
            if let sms = barcode.sms {
                dict["sms"] = processSms(sms)
            }
        case .geographicCoordinates:
            if let geo = barcode.geoPoint {
                dict["geo"] = processGeo(geo)
            }
        case .contactInfo:
            if let contact = barcode.contactInfo {
                dict["contact"] = processContact(contact)
            }
        case .calendarEvent:
            if let event = barcode.calendarEvent {
                dict["calendarEvent"] = processCalendarEvent(event)
            }
        case .driversLicense:
            if let license = barcode.driverLicense {
                dict["driverLicense"] = processDriverLicense(license)
            }
        default:
            break
        }
    }

    private func processWifi(_ wifi: BarcodeWifi) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["ssid"] = wifi.ssid ?? ""
        dict["password"] = wifi.password ?? ""

        let encryptionType: String
        switch wifi.type {
        case .open: encryptionType = "open"
        case .WPA: encryptionType = "wpa"
        case .WEP: encryptionType = "wep"
        default: encryptionType = "unknown"
        }
        dict["encryptionType"] = encryptionType

        return dict
    }

    private func processSms(_ sms: BarcodeSMS) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["phoneNumber"] = sms.phoneNumber ?? ""
        dict["message"] = sms.message ?? ""
        return dict
    }

    private func processGeo(_ geo: BarcodeGeoPoint) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["latitude"] = geo.latitude
        dict["longitude"] = geo.longitude
        return dict
    }

    private func processContact(_ contact: BarcodeContactInfo) -> [String: Any] {
        var dict: [String: Any] = [:]

        if let name = contact.name {
            let firstName = name.first ?? ""
            let lastName = name.last ?? ""
            let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            if !fullName.isEmpty {
                dict["name"] = fullName
            }
        }

        if let organization = contact.organization, !organization.isEmpty {
            dict["organization"] = organization
        }

        if let phones = contact.phones, !phones.isEmpty {
            dict["phones"] = phones.compactMap { $0.number }
        }

        if let emails = contact.emails, !emails.isEmpty {
            dict["emails"] = emails.compactMap { $0.address }
        }

        if let urls = contact.urls, !urls.isEmpty {
            dict["urls"] = urls
        }

        if let addresses = contact.addresses, !addresses.isEmpty {
            dict["addresses"] = addresses.compactMap { $0.addressLines?.joined(separator: ", ") }
        }

        return dict
    }

    // Reusable DateFormatter to avoid expensive allocations per frame
    private static let calendarEventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()

    private func processCalendarEvent(_ event: BarcodeCalendarEvent) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["summary"] = event.summary ?? ""
        dict["description"] = event.eventDescription ?? ""
        dict["location"] = event.location ?? ""

        if let start = event.start {
            dict["start"] = Self.calendarEventDateFormatter.string(from: start)
        }
        if let end = event.end {
            dict["end"] = Self.calendarEventDateFormatter.string(from: end)
        }

        return dict
    }

    private func processDriverLicense(_ license: BarcodeDriverLicense) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["firstName"] = license.firstName ?? ""
        dict["lastName"] = license.lastName ?? ""
        dict["middleName"] = license.middleName ?? ""
        dict["gender"] = license.gender ?? ""
        dict["addressStreet"] = license.addressStreet ?? ""
        dict["addressCity"] = license.addressCity ?? ""
        dict["addressState"] = license.addressState ?? ""
        dict["addressZip"] = license.addressZip ?? ""
        dict["licenseNumber"] = license.licenseNumber ?? ""
        dict["birthDate"] = license.birthDate ?? ""
        dict["issuingCountry"] = license.issuingCountry ?? ""
        return dict
    }

    // MARK: - Geometry Processing

    private func processRect(_ rect: CGRect) -> [String: CGFloat] {
        var dict: [String: CGFloat] = [:]
        dict["x"] = rect.midX
        dict["y"] = rect.midY
        dict["width"] = rect.width
        dict["height"] = rect.height
        return dict
    }

    private func processCornerPoints(_ cornerPoints: [NSValue]?) -> [[String: Int]] {
        guard let cornerPoints = cornerPoints else { return [] }
        var result: [[String: Int]] = []
        for pointValue in cornerPoints {
            let point = pointValue.cgPointValue
            var pointDict: [String: Int] = [:]
            pointDict["x"] = Int(point.x)
            pointDict["y"] = Int(point.y)
            result.append(pointDict)
        }
        return result
    }
}
