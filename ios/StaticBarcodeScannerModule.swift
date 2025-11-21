//
//  StaticBarcodeScannerModule.swift
//  react-native-vision-camera-ml-kit
//

import Foundation
import React
import MLKitVision
import MLKitBarcodeScanning
import Photos

@objc(StaticBarcodeScannerModule)
class StaticBarcodeScannerModule: NSObject {

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }

    @objc
    func scanBarcode(_ options: NSDictionary,
                     resolver resolve: @escaping RCTPromiseResolveBlock,
                     rejecter reject: @escaping RCTPromiseRejectBlock) {
        let startTime = Date()

        guard let uri = options["uri"] as? String else {
            reject("INVALID_URI", "URI is required", nil)
            return
        }

        Logger.debug("Scanning barcode from static image: \(uri)")

        // Parse formats if specified
        let formats = options["formats"] as? [String]
        var scannerOptions: BarcodeScannerOptions

        if let formats = formats, !formats.isEmpty {
            var combinedFormats: BarcodeFormat = []
            for formatString in formats {
                if let parsedFormat = parseBarcodeFormat(formatString) {
                    combinedFormats.insert(parsedFormat)
                }
            }

            if combinedFormats.isEmpty {
                scannerOptions = BarcodeScannerOptions(formats: .all)
            } else {
                scannerOptions = BarcodeScannerOptions(formats: combinedFormats)
            }
        } else {
            scannerOptions = BarcodeScannerOptions(formats: .all)
        }

        let scanner = BarcodeScanner.barcodeScanner(options: scannerOptions)

        // Load image from URI
        loadImage(from: uri) { [weak self] image, error in
            guard let self = self else { return }

            if let error = error {
                Logger.error("Failed to load image from URI: \(uri)", error: error)
                reject("IMAGE_LOAD_ERROR", "Failed to load image: \(error.localizedDescription)", error)
                return
            }

            guard let image = image else {
                reject("IMAGE_LOAD_ERROR", "Failed to load image: image is nil", nil)
                return
            }

            let visionImage = VisionImage(image: image)

            // Process image
            scanner.process(visionImage) { barcodes, error in
                let processingTime = Int64(Date().timeIntervalSince(startTime) * 1000)

                if let error = error {
                    Logger.error("Error during static barcode scanning", error: error)
                    Logger.performance("Static barcode scanning processing (error)", durationMs: processingTime)
                    reject("SCANNING_ERROR", "Barcode scanning failed: \(error.localizedDescription)", error)
                    return
                }

                Logger.performance("Static barcode scanning processing", durationMs: processingTime)

                guard let barcodes = barcodes, !barcodes.isEmpty else {
                    Logger.debug("No barcodes detected in static image")
                    resolve(NSNull())
                    return
                }

                Logger.debug("Barcodes detected in static image: \(barcodes.count) barcode(s)")

                let result: [String: Any] = [
                    "barcodes": self.processBarcodes(barcodes)
                ]

                resolve(result)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadImage(from uri: String, completion: @escaping (UIImage?, Error?) -> Void) {
        if uri.hasPrefix("file://") {
            guard let url = URL(string: uri), let image = UIImage(contentsOfFile: url.path) else {
                completion(nil, NSError(domain: "ImageLoadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from file path"]))
                return
            }
            completion(image, nil)
        } else if uri.hasPrefix("ph://") {
            let assetId = String(uri.dropFirst(5))
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)

            guard let asset = fetchResult.firstObject else {
                completion(nil, NSError(domain: "ImageLoadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Photo asset not found"]))
                return
            }

            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { result, _ in
                if let image = result {
                    completion(image, nil)
                } else {
                    completion(nil, NSError(domain: "ImageLoadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from Photos"]))
                }
            }
        } else {
            if let image = UIImage(contentsOfFile: uri) {
                completion(image, nil)
            } else if let url = URL(string: "file://\(uri)"), let image = UIImage(contentsOfFile: url.path) {
                completion(image, nil)
            } else {
                completion(nil, NSError(domain: "ImageLoadError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from path"]))
            }
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
