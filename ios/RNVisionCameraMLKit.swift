//
//  RNVisionCameraMLKit.swift
//  react-native-vision-camera-ml-kit
//

import Foundation
import VisionCamera

@objc(RNVisionCameraMLKit)
public class RNVisionCameraMLKit: NSObject {

    @objc
    public static func registerPlugins() {
        Logger.info("Registering ML Kit frame processor plugins")

        // Text Recognition v2
        FrameProcessorPluginRegistry.addFrameProcessorPlugin(withName: "scanTextV2") { proxy, options in
            return TextRecognitionPlugin(proxy: proxy, options: options)
        }

        // Barcode Scanning
        FrameProcessorPluginRegistry.addFrameProcessorPlugin(withName: "scanBarcode") { proxy, options in
            return BarcodeScanningPlugin(proxy: proxy, options: options)
        }

        Logger.info("ML Kit frame processor plugins registered successfully")
    }
}

// Auto-registration on load
@objc(RNVisionCameraMLKitLoader)
public class RNVisionCameraMLKitLoader: NSObject {
    @objc
    public static func load() {
        RNVisionCameraMLKit.registerPlugins()
    }
}
