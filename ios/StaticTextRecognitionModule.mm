//
//  StaticTextRecognitionModule.mm
//  react-native-vision-camera-ml-kit
//

#import "StaticTextRecognitionModule.h"
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import "react-native-vision-camera-ml-kit-Swift.h"

// Use @import for MLKit modules (requires modules to be enabled)
@import MLKitTextRecognition;
@import MLKitTextRecognitionChinese;
@import MLKitTextRecognitionDevanagari;
@import MLKitTextRecognitionJapanese;
@import MLKitTextRecognitionKorean;
@import MLKitVision;
@import Photos;

@implementation StaticTextRecognitionModule

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(recognizeText:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSDate *startTime = [NSDate date];

    @try {
        NSString *uri = options[@"uri"];
        if (!uri) {
            reject(@"INVALID_URI", @"URI is required", nil);
            return;
        }

        NSString *language = options[@"language"] ?: @"latin";
        NSNumber *orientationNum = options[@"orientation"];
        int orientation = orientationNum ? [orientationNum intValue] : 0;

        [Logger debugWithMessage:[NSString stringWithFormat:@"Recognizing text from static image: %@ (language: %@, orientation: %d)",
                      uri, language, orientation]];

        // Create recognizer based on language
        MLKTextRecognizer *recognizer;
        NSString *lowerLanguage = [language lowercaseString];

        if ([lowerLanguage isEqualToString:@"chinese"]) {
            recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKChineseTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"devanagari"]) {
            recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKDevanagariTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"japanese"]) {
            recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKJapaneseTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"korean"]) {
            recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKKoreanTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"latin"] || [lowerLanguage isEqualToString:@"default"]) {
            recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKTextRecognizerOptions alloc] init]];
        } else {
            [Logger warnWithMessage:[NSString stringWithFormat:@"Unknown language '%@', defaulting to Latin", language]];
            recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKTextRecognizerOptions alloc] init]];
        }

        // Load image from URI
        [self loadImageFromURI:uri completion:^(UIImage *image, NSError *error) {
            if (error) {
                [Logger errorWithMessage:[NSString stringWithFormat:@"Failed to load image from URI: %@", uri] error:error];
                reject(@"IMAGE_LOAD_ERROR", [NSString stringWithFormat:@"Failed to load image: %@", error.localizedDescription], error);
                return;
            }

            if (!image) {
                reject(@"IMAGE_LOAD_ERROR", @"Failed to load image: image is nil", nil);
                return;
            }

            MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
            visionImage.orientation = [self imageOrientation:orientation];

            // Process image
            [recognizer processImage:visionImage
                          completion:^(MLKText *text, NSError *error) {
                NSTimeInterval processingTime = [[NSDate date] timeIntervalSinceDate:startTime] * 1000;

                if (error) {
                    [Logger errorWithMessage:@"Error during static text recognition" error:error];
                    [Logger performanceWithMessage:@"Static text recognition processing (error)" durationMs:(int64_t)processingTime];
                    reject(@"RECOGNITION_ERROR", [NSString stringWithFormat:@"Text recognition failed: %@", error.localizedDescription], error);
                    return;
                }

                [Logger performanceWithMessage:@"Static text recognition processing" durationMs:(int64_t)processingTime];

                if (!text || text.text.length == 0) {
                    [Logger debugWithMessage:@"No text detected in static image"];
                    resolve([NSNull null]);
                    return;
                }

                [Logger debugWithMessage:[NSString stringWithFormat:@"Text detected in static image: %lu characters, %lu blocks",
                              (unsigned long)text.text.length, (unsigned long)text.blocks.count]];

                NSMutableDictionary *result = [NSMutableDictionary dictionary];
                result[@"text"] = text.text;
                result[@"blocks"] = [self processBlocks:text.blocks];

                resolve(result);
            }];
        }];

    } @catch (NSException *exception) {
        [Logger errorWithMessage:[NSString stringWithFormat:@"Unexpected error in static text recognition: %@", exception.reason]];
        reject(@"UNEXPECTED_ERROR", [NSString stringWithFormat:@"Unexpected error: %@", exception.reason], nil);
    }
}

#pragma mark - Helper Methods

- (void)loadImageFromURI:(NSString *)uri completion:(void (^)(UIImage *, NSError *))completion {
    // Handle different URI schemes
    if ([uri hasPrefix:@"file://"]) {
        // File URI
        NSString *filePath = [[NSURL URLWithString:uri] path];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        completion(image, image ? nil : [NSError errorWithDomain:@"ImageLoadError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load image from file path"}]);
    } else if ([uri hasPrefix:@"ph://"]) {
        // Photos framework URI
        NSString *assetId = [uri substringFromIndex:5]; // Remove "ph://"
        PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil];
        if (fetchResult.count > 0) {
            PHAsset *asset = fetchResult.firstObject;
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.synchronous = NO;
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;

            [[PHImageManager defaultManager] requestImageForAsset:asset
                                                       targetSize:PHImageManagerMaximumSize
                                                      contentMode:PHImageContentModeDefault
                                                          options:options
                                                    resultHandler:^(UIImage *result, NSDictionary *info) {
                completion(result, result ? nil : [NSError errorWithDomain:@"ImageLoadError" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load image from Photos"}]);
            }];
        } else {
            completion(nil, [NSError errorWithDomain:@"ImageLoadError" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Photo asset not found"}]);
        }
    } else if ([uri hasPrefix:@"assets-library://"]) {
        // Asset library URI (deprecated but still supported)
        NSURL *url = [NSURL URLWithString:uri];
        completion(nil, [NSError errorWithDomain:@"ImageLoadError" code:4 userInfo:@{NSLocalizedDescriptionKey: @"assets-library:// URIs are deprecated"}]);
    } else {
        // Try as file path
        NSString *filePath = uri;
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        if (!image) {
            // Try with file:// prefix
            filePath = [@"file://" stringByAppendingString:uri];
            NSURL *url = [NSURL URLWithString:filePath];
            image = [UIImage imageWithContentsOfFile:url.path];
        }
        completion(image, image ? nil : [NSError errorWithDomain:@"ImageLoadError" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load image from path"}]);
    }
}

- (UIImageOrientation)imageOrientation:(int)orientation {
    switch (orientation) {
        case 0: return UIImageOrientationUp;
        case 90: return UIImageOrientationRight;
        case 180: return UIImageOrientationDown;
        case 270: return UIImageOrientationLeft;
        default: return UIImageOrientationUp;
    }
}

- (NSArray*)processBlocks:(NSArray<MLKTextBlock*>*)blocks {
    NSMutableArray *blockArray = [NSMutableArray array];

    for (MLKTextBlock *block in blocks) {
        NSMutableDictionary *blockDict = [NSMutableDictionary dictionary];
        blockDict[@"text"] = block.text;
        blockDict[@"frame"] = [self processRect:block.frame];
        blockDict[@"cornerPoints"] = [self processCornerPoints:block.cornerPoints];
        blockDict[@"lines"] = [self processLines:block.lines];

        if (block.recognizedLanguages.count > 0) {
            MLKTextRecognizedLanguage *lang = block.recognizedLanguages.firstObject;
            if (lang.languageCode) {
                blockDict[@"recognizedLanguage"] = lang.languageCode;
            }
        }

        [blockArray addObject:blockDict];
    }

    return blockArray;
}

- (NSArray*)processLines:(NSArray<MLKTextLine*>*)lines {
    NSMutableArray *lineArray = [NSMutableArray array];

    for (MLKTextLine *line in lines) {
        NSMutableDictionary *lineDict = [NSMutableDictionary dictionary];
        lineDict[@"text"] = line.text;
        lineDict[@"frame"] = [self processRect:line.frame];
        lineDict[@"cornerPoints"] = [self processCornerPoints:line.cornerPoints];
        lineDict[@"elements"] = [self processElements:line.elements];

        if (line.recognizedLanguages.count > 0) {
            MLKTextRecognizedLanguage *lang = line.recognizedLanguages.firstObject;
            if (lang.languageCode) {
                lineDict[@"recognizedLanguage"] = lang.languageCode;
            }
        }

        [lineArray addObject:lineDict];
    }

    return lineArray;
}

- (NSArray*)processElements:(NSArray<MLKTextElement*>*)elements {
    NSMutableArray *elementArray = [NSMutableArray array];

    for (MLKTextElement *element in elements) {
        NSMutableDictionary *elementDict = [NSMutableDictionary dictionary];
        elementDict[@"text"] = element.text;
        elementDict[@"frame"] = [self processRect:element.frame];
        elementDict[@"cornerPoints"] = [self processCornerPoints:element.cornerPoints];
        elementDict[@"symbols"] = [self processSymbols:element.symbols];

        if (element.recognizedLanguages.count > 0) {
            MLKTextRecognizedLanguage *lang = element.recognizedLanguages.firstObject;
            if (lang.languageCode) {
                elementDict[@"recognizedLanguage"] = lang.languageCode;
            }
        }

        [elementArray addObject:elementDict];
    }

    return elementArray;
}

- (NSArray*)processSymbols:(NSArray<MLKTextSymbol*>*)symbols {
    NSMutableArray *symbolArray = [NSMutableArray array];

    for (MLKTextSymbol *symbol in symbols) {
        NSMutableDictionary *symbolDict = [NSMutableDictionary dictionary];
        symbolDict[@"text"] = symbol.text;
        symbolDict[@"frame"] = [self processRect:symbol.frame];
        symbolDict[@"cornerPoints"] = [self processCornerPoints:symbol.cornerPoints];

        if (symbol.recognizedLanguages.count > 0) {
            MLKTextRecognizedLanguage *lang = symbol.recognizedLanguages.firstObject;
            if (lang.languageCode) {
                symbolDict[@"recognizedLanguage"] = lang.languageCode;
            }
        }

        [symbolArray addObject:symbolDict];
    }

    return symbolArray;
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
