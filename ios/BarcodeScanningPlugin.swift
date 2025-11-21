//
//  BarcodeScanningPlugin.swift
//  react-native-vision-camera-ml-kit
//

import Foundation
import VisionCamera
import MLKitVision
import MLKitBarcodeScanning

@objc(BarcodeScanningPlugin)
public class BarcodeScanningPlugin: FrameProcessorPlugin {

    private var scanner: BarcodeScanner!
    private var detectInvertedBarcodes: Bool = false
    private var tryRotations: Bool = true

    public override init(proxy: VisionCameraProxyHolder, options: [AnyHashable: Any]! = [:]) {
        super.init(proxy: proxy, options: options)

        Logger.info("Initializing barcode scanner")

        // Extract options
        detectInvertedBarcodes = options["detectInvertedBarcodes"] as? Bool ?? false
        if detectInvertedBarcodes {
            Logger.warn("Inverted barcode detection may not be fully supported on iOS. This feature may be Android-only.")
        }

        tryRotations = options["tryRotations"] as? Bool ?? true
        if !tryRotations {
            Logger.info("90 degree rotation attempts DISABLED")
        }

        // Parse formats
        let formats = options["formats"] as? [String]
        var scannerOptions: BarcodeScannerOptions

        if let formats = formats, !formats.isEmpty {
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
                scannerOptions = BarcodeScannerOptions(formats: .all)
            } else {
                Logger.info("Scanning barcode format(s) with combined mask")
                scannerOptions = BarcodeScannerOptions(formats: combinedFormats)
            }
        } else {
            Logger.info("No format filter specified, scanning all barcode formats")
            scannerOptions = BarcodeScannerOptions(formats: .all)
        }

        scanner = BarcodeScanner.barcodeScanner(options: scannerOptions)
        Logger.info("Barcode scanner initialized successfully")
    }

    public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable: Any]?) -> Any? {
        let startTime = Date()

        do {
            let buffer = frame.buffer
            let orientation = getOrientation(frame.orientation)

            Logger.debug("Processing frame: \(frame.width)x\(frame.height), orientation: \(orientation.rawValue)")

            let visionImage = VisionImage(buffer: buffer)
            visionImage.orientation = orientation

            // Process synchronously
            let barcodes = try scanner.results(in: visionImage)

            let processingTime = Int64(Date().timeIntervalSince(startTime) * 1000)
            Logger.performance("Barcode scanning processing", durationMs: processingTime)

            if barcodes.isEmpty {
                Logger.debug("No barcodes detected in frame")
                return nil
            }

            Logger.debug("Barcodes detected: \(barcodes.count) barcode(s)")

            return [
                "barcodes": processBarcodes(barcodes)
            ]

        } catch {
            let processingTime = Int64(Date().timeIntervalSince(startTime) * 1000)
            Logger.error("Exception during barcode scanning: \(error.localizedDescription)")
            Logger.performance("Barcode scanning processing (error)", durationMs: processingTime)
            return nil
        }
    }

    // MARK: - Helper Methods

    private func getOrientation(_ orientationStr: String) -> UIImage.Orientation {
        switch orientationStr {
        case "portrait": return .up
        case "portrait-upside-down": return .down
        case "landscape-left": return .left
        case "landscape-right": return .right
        default: return .up
        }
    }

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

    private func processBarcodes(_ barcodes: [Barcode]) -> [[String: Any]] {
        return barcodes.map { barcode in
            var barcodeDict: [String: Any] = [
                "rawValue": barcode.rawValue ?? "",
                "displayValue": barcode.displayValue ?? "",
                "format": barcodeFormatToString(barcode.format),
                "valueType": valueTypeToString(barcode.valueType),
                "frame": processRect(barcode.frame),
                "cornerPoints": processCornerPoints(barcode.cornerPoints)
            ]

            // Structured data based on type
            switch barcode.valueType {
            case .wiFi:
                if let wifi = barcode.wifi {
                    var wifiDict: [String: Any] = [
                        "ssid": wifi.ssid ?? "",
                        "password": wifi.password ?? ""
                    ]
                    let encryptionType: String
                    switch wifi.type {
                    case .open: encryptionType = "open"
                    case .WPA: encryptionType = "wpa"
                    case .WEP: encryptionType = "wep"
                    default: encryptionType = "unknown"
                    }
                    wifiDict["encryptionType"] = encryptionType
                    barcodeDict["wifi"] = wifiDict
                }

            case .URL:
                if let url = barcode.url?.url {
                    barcodeDict["url"] = url
                }

            case .email:
                if let email = barcode.email?.address {
                    barcodeDict["email"] = email
                }

            case .phone:
                if let phone = barcode.phone?.number {
                    barcodeDict["phone"] = phone
                }

            case .SMS:
                if let sms = barcode.sms {
                    barcodeDict["sms"] = [
                        "phoneNumber": sms.phoneNumber ?? "",
                        "message": sms.message ?? ""
                    ]
                }

            case .geographicCoordinates:
                if let geo = barcode.geoPoint {
                    barcodeDict["geo"] = [
                        "latitude": geo.latitude,
                        "longitude": geo.longitude
                    ]
                }

            case .contactInfo:
                if let contact = barcode.contactInfo {
                    var contactDict: [String: Any] = [:]

                    if let name = contact.name {
                        let fullName = "\(name.first ?? "") \(name.last ?? "")".trimmingCharacters(in: .whitespaces)
                        contactDict["name"] = fullName
                    }

                    contactDict["organization"] = contact.organization ?? ""

                    if let phones = contact.phones {
                        contactDict["phones"] = phones.compactMap { $0.number }
                    }

                    if let emails = contact.emails {
                        contactDict["emails"] = emails.compactMap { $0.address }
                    }

                    if let urls = contact.urls {
                        contactDict["urls"] = urls
                    }

                    if let addresses = contact.addresses {
                        contactDict["addresses"] = addresses.compactMap { $0.addressLines?.joined(separator: ", ") }
                    }

                    barcodeDict["contact"] = contactDict
                }

            case .calendarEvent:
                if let event = barcode.calendarEvent {
                    var eventDict: [String: Any] = [
                        "summary": event.summary ?? "",
                        "description": event.eventDescription ?? "",
                        "location": event.location ?? ""
                    ]

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")

                    if let start = event.start {
                        eventDict["start"] = formatter.string(from: start)
                    }
                    if let end = event.end {
                        eventDict["end"] = formatter.string(from: end)
                    }

                    barcodeDict["calendarEvent"] = eventDict
                }

            case .driversLicense:
                if let license = barcode.driverLicense {
                    barcodeDict["driverLicense"] = [
                        "documentType": license.documentType ?? "",
                        "firstName": license.firstName ?? "",
                        "lastName": license.lastName ?? "",
                        "gender": license.gender ?? "",
                        "addressStreet": license.addressStreet ?? "",
                        "addressCity": license.addressCity ?? "",
                        "addressState": license.addressState ?? "",
                        "addressZip": license.addressZip ?? "",
                        "licenseNumber": license.licenseNumber ?? "",
                        "issueDate": license.issueDate ?? "",
                        "expiryDate": license.expiryDate ?? "",
                        "birthDate": license.birthDate ?? "",
                        "issuingCountry": license.issuingCountry ?? ""
                    ]
                }

            default:
                break
            }

            return barcodeDict
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

    private func processCornerPoints(_ cornerPoints: [NSValue]?) -> [[String: Int]] {
        guard let cornerPoints = cornerPoints else { return [] }
        return cornerPoints.compactMap { $0.cgPointValue }.map { point in
            ["x": Int(point.x), "y": Int(point.y)]
        }
    }
}
