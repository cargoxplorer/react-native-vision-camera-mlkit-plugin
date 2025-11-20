//
//  RNVisionCameraMLKitPackage.mm
//  react-native-vision-camera-ml-kit
//

#import "RNVisionCameraMLKitPackage.h"
#import "TextRecognitionPlugin.h"
#import "BarcodeScanningPlugin.h"
#import "react-native-vision-camera-ml-kit-Swift.h"

#import <VisionCamera/Frame.h>
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>

@implementation RNVisionCameraMLKitPackage

+ (void)load {
    [self registerPlugins];
}

+ (void)registerPlugins {
    [Logger info:@"Registering ML Kit frame processor plugins"];

    // Text Recognition v2
    [FrameProcessorPluginRegistry addFrameProcessorPlugin:@"scanTextV2"
                                              withInitializer:^FrameProcessorPlugin* (VisionCameraProxyHolder* proxy, NSDictionary* options) {
        return [[TextRecognitionPlugin alloc] initWithProxy:proxy withOptions:options];
    }];

    // Barcode Scanning
    [FrameProcessorPluginRegistry addFrameProcessorPlugin:@"scanBarcode"
                                              withInitializer:^FrameProcessorPlugin* (VisionCameraProxyHolder* proxy, NSDictionary* options) {
        return [[BarcodeScanningPlugin alloc] initWithProxy:proxy withOptions:options];
    }];

    [Logger info:@"ML Kit frame processor plugins registered successfully"];
}

@end
