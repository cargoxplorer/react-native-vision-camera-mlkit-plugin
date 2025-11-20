//
//  BarcodeScanningPlugin.mm
//  react-native-vision-camera-ml-kit
//

#import "BarcodeScanningPlugin.h"
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import "react-native-vision-camera-ml-kit-Swift.h"

#import <MLKitBarcodeScanning/MLKitBarcodeScanning.h>
#import <MLKitVision/MLKitVision.h>

// Explicit imports for MLKit barcode types
#import <MLKitBarcodeScanning/MLKBarcode.h>
#import <MLKitBarcodeScanning/MLKBarcodeAddress.h>
#import <MLKitBarcodeScanning/MLKBarcodeContactInfo.h>
#import <MLKitBarcodeScanning/MLKBarcodeDriverLicense.h>
#import <MLKitBarcodeScanning/MLKBarcodeEmail.h>
#import <MLKitBarcodeScanning/MLKBarcodeGeoPoint.h>
#import <MLKitBarcodeScanning/MLKBarcodePersonName.h>
#import <MLKitBarcodeScanning/MLKBarcodePhone.h>
#import <MLKitBarcodeScanning/MLKBarcodeSMS.h>
#import <MLKitBarcodeScanning/MLKBarcodeURLBookmark.h>
#import <MLKitBarcodeScanning/MLKBarcodeWiFi.h>
#import <MLKitBarcodeScanning/MLKBarcodeCalendarEvent.h>

@interface BarcodeScanningPlugin ()
@property (nonatomic, strong) MLKBarcodeScanner *scanner;
@property (nonatomic, assign) BOOL detectInvertedBarcodes;
@property (nonatomic, assign) BOOL tryRotations;
@end

@implementation BarcodeScanningPlugin

- (instancetype)initWithProxy:(VisionCameraProxyHolder*)proxy
                  withOptions:(NSDictionary*)options {
    if (self = [super initWithProxy:proxy withOptions:options]) {
        [Logger infoWithMessage:@"Initializing barcode scanner"];

        // Extract options
        self.detectInvertedBarcodes = [options[@"detectInvertedBarcodes"] boolValue];
        if (self.detectInvertedBarcodes) {
            [Logger warnWithMessage:@"⚠️ Inverted barcode detection may not be fully supported on iOS. This feature may be Android-only."];
        }

        self.tryRotations = options[@"tryRotations"] ? [options[@"tryRotations"] boolValue] : YES;
        if (!self.tryRotations) {
            [Logger infoWithMessage:@"90 degree rotation attempts DISABLED"];
        }

        // Parse formats
        NSArray *formats = options[@"formats"];
        MLKBarcodeScannerOptions *scannerOptions;

        if (formats && formats.count > 0) {
            [Logger debugWithMessage:[NSString stringWithFormat:@"Parsing %lu barcode format(s) from options", (unsigned long)formats.count]];

            MLKBarcodeFormat combinedFormats = 0;
            for (NSString *formatString in formats) {
                MLKBarcodeFormat parsedFormat = [self parseBarcodeFormat:formatString];
                if (parsedFormat != 0) {
                    combinedFormats |= parsedFormat;
                    [Logger debugWithMessage:[NSString stringWithFormat:@"Successfully parsed format: '%@'", formatString]];
                } else {
                    [Logger errorWithMessage:[NSString stringWithFormat:@"FAILED to parse barcode format: '%@'", formatString] error:nil];
                }
            }

            if (combinedFormats == 0) {
                [Logger errorWithMessage:@"No valid barcode formats could be parsed! Falling back to all formats" error:nil];
                scannerOptions = [[MLKBarcodeScannerOptions alloc] initWithFormats:MLKBarcodeFormatAll];
            } else {
                [Logger infoWithMessage:[NSString stringWithFormat:@"Scanning barcode format(s) with combined mask: %lu", (unsigned long)combinedFormats]];
                scannerOptions = [[MLKBarcodeScannerOptions alloc] initWithFormats:combinedFormats];
            }
        } else {
            [Logger infoWithMessage:@"No format filter specified, scanning all barcode formats"];
            scannerOptions = [[MLKBarcodeScannerOptions alloc] initWithFormats:MLKBarcodeFormatAll];
        }

        self.scanner = [MLKBarcodeScanner barcodeScannerWithOptions:scannerOptions];
        [Logger infoWithMessage:@"Barcode scanner initialized successfully"];
    }
    return self;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
    NSDate *startTime = [NSDate date];

    @try {
        CMSampleBufferRef buffer = frame.buffer;
        UIImageOrientation orientation = [self getOrientation:frame.orientation];

        if ([Logger isDebugEnabled]) {
            [Logger debugWithMessage:[NSString stringWithFormat:@"Processing frame: %dx%d, orientation: %ld",
                          (int)frame.width, (int)frame.height, (long)orientation]];
        }

        MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithBuffer:buffer];
        visionImage.orientation = orientation;

        // Process synchronously (blocking)
        NSError *error = nil;
        NSArray<MLKBarcode *> *barcodes = [self.scanner resultsInImage:visionImage error:&error];

        NSTimeInterval processingTime = [[NSDate date] timeIntervalSinceDate:startTime] * 1000;
        [Logger performanceWithMessage:@"Barcode scanning processing" durationMs:(int64_t)processingTime];

        if (error != nil) {
            [Logger errorWithMessage:@"Error during barcode scanning" error:error];
            return nil;
        }

        if (!barcodes || barcodes.count == 0) {
            if ([Logger isDebugEnabled]) {
                [Logger debugWithMessage:@"No barcodes detected in frame"];
            }
            return nil;
        }

        if ([Logger isDebugEnabled]) {
            [Logger debugWithMessage:[NSString stringWithFormat:@"Barcodes detected: %lu barcode(s)", (unsigned long)barcodes.count]];
        }

        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        result[@"barcodes"] = [self processBarcodes:barcodes];

        return result;

    } @catch (NSException *exception) {
        NSTimeInterval processingTime = [[NSDate date] timeIntervalSinceDate:startTime] * 1000;
        [Logger errorWithMessage:[NSString stringWithFormat:@"Exception during barcode scanning: %@", exception.reason] error:nil];
        [Logger performanceWithMessage:@"Barcode scanning processing (error)" durationMs:(int64_t)processingTime];
        return nil;
    }
}

#pragma mark - Helper Methods

- (UIImageOrientation)getOrientation:(NSString*)orientationStr {
    if ([orientationStr isEqualToString:@"portrait"]) return UIImageOrientationUp;
    if ([orientationStr isEqualToString:@"portrait-upside-down"]) return UIImageOrientationDown;
    if ([orientationStr isEqualToString:@"landscape-left"]) return UIImageOrientationLeft;
    if ([orientationStr isEqualToString:@"landscape-right"]) return UIImageOrientationRight;
    return UIImageOrientationUp;
}

- (MLKBarcodeFormat)parseBarcodeFormat:(NSString *)format {
    NSString *lowerFormat = [format lowercaseString];

    if ([lowerFormat isEqualToString:@"codabar"]) return MLKBarcodeFormatCodaBar;
    if ([lowerFormat isEqualToString:@"code39"]) return MLKBarcodeFormatCode39;
    if ([lowerFormat isEqualToString:@"code93"]) return MLKBarcodeFormatCode93;
    if ([lowerFormat isEqualToString:@"code128"]) return MLKBarcodeFormatCode128;
    if ([lowerFormat isEqualToString:@"ean8"]) return MLKBarcodeFormatEAN8;
    if ([lowerFormat isEqualToString:@"ean13"]) return MLKBarcodeFormatEAN13;
    if ([lowerFormat isEqualToString:@"itf"]) return MLKBarcodeFormatITF;
    if ([lowerFormat isEqualToString:@"upca"]) return MLKBarcodeFormatUPCA;
    if ([lowerFormat isEqualToString:@"upce"]) return MLKBarcodeFormatUPCE;
    if ([lowerFormat isEqualToString:@"aztec"]) return MLKBarcodeFormatAztec;
    if ([lowerFormat isEqualToString:@"datamatrix"]) return MLKBarcodeFormatDataMatrix;
    if ([lowerFormat isEqualToString:@"pdf417"]) return MLKBarcodeFormatPDF417;
    if ([lowerFormat isEqualToString:@"qrcode"]) return MLKBarcodeFormatQRCode;

    [Logger warnWithMessage:[NSString stringWithFormat:@"Unknown barcode format: %@", format]];
    return 0;
}

- (NSString*)barcodeFormatToString:(MLKBarcodeFormat)format {
    switch (format) {
        case MLKBarcodeFormatCodaBar: return @"codabar";
        case MLKBarcodeFormatCode39: return @"code39";
        case MLKBarcodeFormatCode93: return @"code93";
        case MLKBarcodeFormatCode128: return @"code128";
        case MLKBarcodeFormatEAN8: return @"ean8";
        case MLKBarcodeFormatEAN13: return @"ean13";
        case MLKBarcodeFormatITF: return @"itf";
        case MLKBarcodeFormatUPCA: return @"upca";
        case MLKBarcodeFormatUPCE: return @"upce";
        case MLKBarcodeFormatAztec: return @"aztec";
        case MLKBarcodeFormatDataMatrix: return @"datamatrix";
        case MLKBarcodeFormatPDF417: return @"pdf417";
        case MLKBarcodeFormatQRCode: return @"qrcode";
        default: return @"unknown";
    }
}

- (NSString*)valueTypeToString:(MLKBarcodeValueType)valueType {
    switch (valueType) {
        case MLKBarcodeValueTypeText: return @"text";
        case MLKBarcodeValueTypeURL: return @"url";
        case MLKBarcodeValueTypeEmail: return @"email";
        case MLKBarcodeValueTypePhone: return @"phone";
        case MLKBarcodeValueTypeSMS: return @"sms";
        case MLKBarcodeValueTypeWiFi: return @"wifi";
        case MLKBarcodeValueTypeGeo: return @"geo";
        case MLKBarcodeValueTypeContactInfo: return @"contact";
        case MLKBarcodeValueTypeCalendarEvent: return @"calendarEvent";
        case MLKBarcodeValueTypeDriverLicense: return @"driverLicense";
        default: return @"unknown";
    }
}

- (NSArray*)processBarcodes:(NSArray<MLKBarcode*>*)barcodes {
    NSMutableArray *barcodeArray = [NSMutableArray array];

    for (MLKBarcode *barcode in barcodes) {
        NSMutableDictionary *barcodeDict = [NSMutableDictionary dictionary];
        barcodeDict[@"rawValue"] = barcode.rawValue ?: @"";
        barcodeDict[@"displayValue"] = barcode.displayValue ?: @"";
        barcodeDict[@"format"] = [self barcodeFormatToString:barcode.format];
        barcodeDict[@"valueType"] = [self valueTypeToString:barcode.valueType];

        // Bounding box and corner points
        barcodeDict[@"frame"] = [self processRect:barcode.frame];
        barcodeDict[@"cornerPoints"] = [self processCornerPoints:barcode.cornerPoints];

        // Structured data based on type
        switch (barcode.valueType) {
            case MLKBarcodeValueTypeWiFi: {
                if (barcode.wifi) {
                    NSMutableDictionary *wifiDict = [NSMutableDictionary dictionary];
                    wifiDict[@"ssid"] = barcode.wifi.ssid ?: @"";
                    wifiDict[@"password"] = barcode.wifi.password ?: @"";

                    NSString *encryptionType;
                    switch (barcode.wifi.type) {
                        case MLKBarcodeWiFiEncryptionTypeOpen:
                            encryptionType = @"open";
                            break;
                        case MLKBarcodeWiFiEncryptionTypeWPA:
                            encryptionType = @"wpa";
                            break;
                        case MLKBarcodeWiFiEncryptionTypeWEP:
                            encryptionType = @"wep";
                            break;
                        default:
                            encryptionType = @"unknown";
                            break;
                    }
                    wifiDict[@"encryptionType"] = encryptionType;
                    barcodeDict[@"wifi"] = wifiDict;
                }
                break;
            }
            case MLKBarcodeValueTypeURL: {
                if (barcode.URL && barcode.URL.url) {
                    barcodeDict[@"url"] = barcode.URL.url;
                }
                break;
            }
            case MLKBarcodeValueTypeEmail: {
                if (barcode.email && barcode.email.address) {
                    barcodeDict[@"email"] = barcode.email.address;
                }
                break;
            }
            case MLKBarcodeValueTypePhone: {
                if (barcode.phone && barcode.phone.number) {
                    barcodeDict[@"phone"] = barcode.phone.number;
                }
                break;
            }
            case MLKBarcodeValueTypeSMS: {
                if (barcode.sms) {
                    NSMutableDictionary *smsDict = [NSMutableDictionary dictionary];
                    smsDict[@"phoneNumber"] = barcode.sms.phoneNumber ?: @"";
                    smsDict[@"message"] = barcode.sms.message ?: @"";
                    barcodeDict[@"sms"] = smsDict;
                }
                break;
            }
            case MLKBarcodeValueTypeGeo: {
                if (barcode.geoPoint) {
                    NSMutableDictionary *geoDict = [NSMutableDictionary dictionary];
                    geoDict[@"latitude"] = @(barcode.geoPoint.latitude);
                    geoDict[@"longitude"] = @(barcode.geoPoint.longitude);
                    barcodeDict[@"geo"] = geoDict;
                }
                break;
            }
            case MLKBarcodeValueTypeContactInfo: {
                if (barcode.contactInfo) {
                    NSMutableDictionary *contactDict = [NSMutableDictionary dictionary];

                    if (barcode.contactInfo.name) {
                        NSString *firstName = barcode.contactInfo.name.first ?: @"";
                        NSString *lastName = barcode.contactInfo.name.last ?: @"";
                        contactDict[@"name"] = [[NSString stringWithFormat:@"%@ %@", firstName, lastName] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    }

                    contactDict[@"organization"] = barcode.contactInfo.organization ?: @"";

                    if (barcode.contactInfo.phones) {
                        NSMutableArray *phonesArray = [NSMutableArray array];
                        for (MLKBarcodePhone *phone in barcode.contactInfo.phones) {
                            [phonesArray addObject:phone.number ?: @""];
                        }
                        contactDict[@"phones"] = phonesArray;
                    }

                    if (barcode.contactInfo.emails) {
                        NSMutableArray *emailsArray = [NSMutableArray array];
                        for (MLKBarcodeEmail *email in barcode.contactInfo.emails) {
                            [emailsArray addObject:email.address ?: @""];
                        }
                        contactDict[@"emails"] = emailsArray;
                    }

                    if (barcode.contactInfo.URLs) {
                        NSMutableArray *urlsArray = [NSMutableArray array];
                        for (NSString *url in barcode.contactInfo.URLs) {
                            [urlsArray addObject:url ?: @""];
                        }
                        contactDict[@"urls"] = urlsArray;
                    }

                    if (barcode.contactInfo.addresses) {
                        NSMutableArray *addressesArray = [NSMutableArray array];
                        for (MLKBarcodeAddress *address in barcode.contactInfo.addresses) {
                            NSString *addressStr = [address.addressLines componentsJoinedByString:@", "] ?: @"";
                            [addressesArray addObject:addressStr];
                        }
                        contactDict[@"addresses"] = addressesArray;
                    }

                    barcodeDict[@"contact"] = contactDict;
                }
                break;
            }
            case MLKBarcodeValueTypeCalendarEvent: {
                if (barcode.calendarEvent) {
                    NSMutableDictionary *eventDict = [NSMutableDictionary dictionary];
                    eventDict[@"summary"] = barcode.calendarEvent.summary ?: @"";
                    eventDict[@"description"] = barcode.calendarEvent.eventDescription ?: @"";
                    eventDict[@"location"] = barcode.calendarEvent.location ?: @"";

                    if (barcode.calendarEvent.start) {
                        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                        formatter.dateFormat = @"yyyyMMdd'T'HHmmss'Z'";
                        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
                        eventDict[@"start"] = [formatter stringFromDate:barcode.calendarEvent.start];
                    }

                    if (barcode.calendarEvent.end) {
                        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                        formatter.dateFormat = @"yyyyMMdd'T'HHmmss'Z'";
                        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
                        eventDict[@"end"] = [formatter stringFromDate:barcode.calendarEvent.end];
                    }

                    barcodeDict[@"calendarEvent"] = eventDict;
                }
                break;
            }
            case MLKBarcodeValueTypeDriverLicense: {
                if (barcode.driverLicense) {
                    NSMutableDictionary *licenseDict = [NSMutableDictionary dictionary];
                    licenseDict[@"documentType"] = barcode.driverLicense.documentType ?: @"";
                    licenseDict[@"firstName"] = barcode.driverLicense.firstName ?: @"";
                    licenseDict[@"lastName"] = barcode.driverLicense.lastName ?: @"";
                    licenseDict[@"gender"] = barcode.driverLicense.gender ?: @"";
                    licenseDict[@"addressStreet"] = barcode.driverLicense.addressStreet ?: @"";
                    licenseDict[@"addressCity"] = barcode.driverLicense.addressCity ?: @"";
                    licenseDict[@"addressState"] = barcode.driverLicense.addressState ?: @"";
                    licenseDict[@"addressZip"] = barcode.driverLicense.addressZip ?: @"";
                    licenseDict[@"licenseNumber"] = barcode.driverLicense.licenseNumber ?: @"";
                    licenseDict[@"issueDate"] = barcode.driverLicense.issueDate ?: @"";
                    licenseDict[@"expiryDate"] = barcode.driverLicense.expiryDate ?: @"";
                    licenseDict[@"birthDate"] = barcode.driverLicense.birthDate ?: @"";
                    licenseDict[@"issuingCountry"] = barcode.driverLicense.issuingCountry ?: @"";
                    barcodeDict[@"driverLicense"] = licenseDict;
                }
                break;
            }
            default:
                break;
        }

        [barcodeArray addObject:barcodeDict];
    }

    return barcodeArray;
}

- (NSDictionary*)processRect:(CGRect)rect {
    NSMutableDictionary *rectDict = [NSMutableDictionary dictionary];
    rectDict[@"x"] = @(CGRectGetMidX(rect));
    rectDict[@"y"] = @(CGRectGetMidY(rect));
    rectDict[@"width"] = @(CGRectGetWidth(rect));
    rectDict[@"height"] = @(CGRectGetHeight(rect));
    return rectDict;
}

- (NSArray*)processCornerPoints:(NSArray<NSValue*>*)cornerPoints {
    NSMutableArray *pointsArray = [NSMutableArray array];

    for (NSValue *pointValue in cornerPoints) {
        CGPoint point = [pointValue CGPointValue];
        NSMutableDictionary *pointDict = [NSMutableDictionary dictionary];
        pointDict[@"x"] = @((int)point.x);
        pointDict[@"y"] = @((int)point.y);
        [pointsArray addObject:pointDict];
    }

    return pointsArray;
}

@end
