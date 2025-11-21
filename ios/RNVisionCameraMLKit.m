//
//  RNVisionCameraMLKit.m
//  react-native-vision-camera-ml-kit
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

// Import the Swift header
#if __has_include("react_native_vision_camera_mlkit_plugin-Swift.h")
#import "react_native_vision_camera_mlkit_plugin-Swift.h"
#else
#import <react_native_vision_camera_mlkit_plugin/react_native_vision_camera_mlkit_plugin-Swift.h>
#endif

@interface RNVisionCameraMLKitBridge : NSObject
@end

@implementation RNVisionCameraMLKitBridge

+ (void)load {
    [RNVisionCameraMLKit registerPlugins];
}

@end

// Export Static Modules to React Native
@interface RCT_EXTERN_MODULE(StaticTextRecognitionModule, NSObject)
RCT_EXTERN_METHOD(recognizeText:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
@end

@interface RCT_EXTERN_MODULE(StaticBarcodeScannerModule, NSObject)
RCT_EXTERN_METHOD(scanBarcode:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
@end
