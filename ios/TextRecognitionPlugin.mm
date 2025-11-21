//
//  TextRecognitionPlugin.mm
//  react-native-vision-camera-ml-kit
//

#import "TextRecognitionPlugin.h"
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import "react-native-vision-camera-ml-kit-Swift.h"

@import MLKitTextRecognitionCommon;
@import MLKitTextRecognition;
@import MLKitTextRecognitionChinese;
@import MLKitTextRecognitionDevanagari;
@import MLKitTextRecognitionJapanese;
@import MLKitTextRecognitionKorean;
@import MLKitVision;

@interface TextRecognitionPlugin ()
@property (nonatomic, strong) MLKTextRecognizer *recognizer;
@end

@implementation TextRecognitionPlugin

- (instancetype)initWithProxy:(VisionCameraProxyHolder*)proxy
                  withOptions:(NSDictionary*)options {
    if (self = [super initWithProxy:proxy withOptions:options]) {
        NSString *language = options[@"language"] ?: @"latin";
        [Logger infoWithMessage:[NSString stringWithFormat:@"Initializing text recognition with language: %@", language]];

        // Create recognizer based on language
        NSString *lowerLanguage = [language lowercaseString];

        if ([lowerLanguage isEqualToString:@"chinese"]) {
            self.recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKChineseTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"devanagari"]) {
            self.recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKDevanagariTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"japanese"]) {
            self.recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKJapaneseTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"korean"]) {
            self.recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKKoreanTextRecognizerOptions alloc] init]];
        } else if ([lowerLanguage isEqualToString:@"latin"] || [lowerLanguage isEqualToString:@"default"]) {
            self.recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKTextRecognizerOptions alloc] init]];
        } else {
            [Logger warnWithMessage:[NSString stringWithFormat:@"Unknown language '%@', defaulting to Latin", language]];
            self.recognizer = [MLKTextRecognizer textRecognizerWithOptions:[[MLKTextRecognizerOptions alloc] init]];
        }
        [Logger infoWithMessage:@"Text recognition initialized successfully"];
    }
    return self;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
    NSDate *startTime = [NSDate date];

    @try {
        CMSampleBufferRef buffer = frame.buffer;
        UIImageOrientation orientation = [self getOrientation:frame.orientation];

        MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithBuffer:buffer];
        visionImage.orientation = orientation;

        [Logger debugWithMessage:[NSString stringWithFormat:@"Processing frame: %dx%d, orientation: %ld",
                      (int)frame.width, (int)frame.height, (long)orientation]];

        // Process synchronously (blocking)
        NSError *error = nil;
        MLKText *text = [self.recognizer resultsInImage:visionImage error:&error];

        NSTimeInterval processingTime = [[NSDate date] timeIntervalSinceDate:startTime] * 1000;
        [Logger performanceWithMessage:@"Text recognition processing" durationMs:(int64_t)processingTime];

        if (error != nil) {
            [Logger errorWithMessage:@"Error during text recognition" error:error];
            return nil;
        }

        if (text == nil || text.text.length == 0) {
            [Logger debugWithMessage:@"No text detected in frame"];
            return nil;
        }

        [Logger debugWithMessage:[NSString stringWithFormat:@"Text detected: %lu characters, %lu blocks",
                      (unsigned long)text.text.length, (unsigned long)text.blocks.count]];

        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        result[@"text"] = text.text;
        result[@"blocks"] = [self processBlocks:text.blocks];

        return result;

    } @catch (NSException *exception) {
        NSTimeInterval processingTime = [[NSDate date] timeIntervalSinceDate:startTime] * 1000;
        [Logger errorWithMessage:[NSString stringWithFormat:@"Exception during text recognition: %@", exception.reason]];
        [Logger performanceWithMessage:@"Text recognition processing (error)" durationMs:(int64_t)processingTime];
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
