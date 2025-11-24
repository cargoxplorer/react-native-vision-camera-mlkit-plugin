//
//  RNVisionCameraMLKit.m
//  react-native-vision-camera-ml-kit
//
// This file exports the static native modules to React Native.
// Frame Processor Plugins are registered in separate files:
// - TextRecognitionPluginRegistration.m
// - BarcodeScanningPluginRegistration.m
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(StaticTextRecognitionModule, NSObject)
RCT_EXTERN_METHOD(recognizeText:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
+ (BOOL)requiresMainQueueSetup { return NO; }
@end

@interface RCT_EXTERN_MODULE(StaticBarcodeScannerModule, NSObject)
RCT_EXTERN_METHOD(scanBarcode:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
+ (BOOL)requiresMainQueueSetup { return NO; }
@end
