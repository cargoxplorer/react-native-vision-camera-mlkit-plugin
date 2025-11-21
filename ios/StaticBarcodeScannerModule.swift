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

        let formats = options["formats"] as? [String]
        let scannerOptions = createScannerOptions(formats: formats)
        let scanner = BarcodeScanner.barcodeScanner(options: scannerOptions)

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

                let result: [String: Any] = ["barcodes": self.processBarcodes(barcodes)]
                resolve(result)
            }
        }
    }

    // MARK: - Scanner Options

    private func createScannerOptions(formats: [String]?) -> BarcodeScannerOptions {
        guard let formats = formats, !formats.isEmpty else {
            return BarcodeScannerOptions(formats: .all)
        }

        var combinedFormats: BarcodeFormat = []
        for formatString in formats {
            if let parsedFormat = parseBarcodeFormat(formatString) {
                combinedFormats.insert(parsedFormat)
            }
        }

        if combinedFormats.isEmpty {
            return BarcodeScannerOptions(formats: .all)
        }

        return BarcodeScannerOptions(formats: combinedFormats)
    }

    // MARK: - Image Loading

    private func loadImage(from uri: String, completion: @escaping (UIImage?, Error?) -> Void) {
        if uri.hasPrefix("file://") {
            guard let url = URL(string: uri), let image = UIImage(contentsOfFile: url.path) else {
                let error = NSError(domain: "ImageLoadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from file path"])
                completion(nil, error)
                return
            }
            completion(image, nil)
        } else if uri.hasPrefix("ph://") {
            loadFromPhotos(assetId: String(uri.dropFirst(5)), completion: completion)
        } else {
            loadFromPath(uri, completion: completion)
        }
    }

    private func loadFromPhotos(assetId: String, completion: @escaping (UIImage?, Error?) -> Void) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)

        guard let asset = fetchResult.firstObject else {
            let error = NSError(domain: "ImageLoadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Photo asset not found"])
            completion(nil, error)
            return
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { result, _ in
            if let image = result {
                completion(image, nil)
            } else {
                let error = NSError(domain: "ImageLoadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from Photos"])
                completion(nil, error)
            }
        }
    }

    private func loadFromPath(_ uri: String, completion: @escaping (UIImage?, Error?) -> Void) {
        if let image = UIImage(contentsOfFile: uri) {
            completion(image, nil)
        } else if let url = URL(string: "file://\(uri)"), let image = UIImage(contentsOfFile: url.path) {
            completion(image, nil)
        } else {
            let error = NSError(domain: "ImageLoadError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from path"])
            completion(nil, error)
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
            dict["name"] = fullName
        }

        dict["organization"] = contact.organization ?? ""

        if let phones = contact.phones {
            dict["phones"] = phones.compactMap { $0.number }
        }

        if let emails = contact.emails {
            dict["emails"] = emails.compactMap { $0.address }
        }

        if let urls = contact.urls {
            dict["urls"] = urls
        }

        if let addresses = contact.addresses {
            dict["addresses"] = addresses.compactMap { $0.addressLines?.joined(separator: ", ") }
        }

        return dict
    }

    private func processCalendarEvent(_ event: BarcodeCalendarEvent) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["summary"] = event.summary ?? ""
        dict["description"] = event.eventDescription ?? ""
        dict["location"] = event.location ?? ""

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")

        if let start = event.start {
            dict["start"] = formatter.string(from: start)
        }
        if let end = event.end {
            dict["end"] = formatter.string(from: end)
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
        dict["expirationDate"] = license.expirationDate ?? ""
        dict["birthDate"] = license.birthDate ?? ""
        dict["issuingCountry"] = license.issuingCountry ?? ""
        dict["licenseType"] = license.licenseType ?? ""
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
