//
//  BarcodeScanningPluginRegistration.m
//  react-native-vision-camera-ml-kit
//

#import <Foundation/Foundation.h>
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>

// Import the Swift header
#if __has_include("react_native_vision_camera_mlkit_plugin/react_native_vision_camera_mlkit_plugin-Swift.h")
#import "react_native_vision_camera_mlkit_plugin/react_native_vision_camera_mlkit_plugin-Swift.h"
#else
#import "react_native_vision_camera_mlkit_plugin-Swift.h"
#endif

VISION_EXPORT_SWIFT_FRAME_PROCESSOR(BarcodeScanningPlugin, scanBarcode)
