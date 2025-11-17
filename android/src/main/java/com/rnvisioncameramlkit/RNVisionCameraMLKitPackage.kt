package com.rnvisioncameramlkit

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.mrousavy.camera.frameprocessors.FrameProcessorPluginRegistry

class RNVisionCameraMLKitPackage : ReactPackage {
  companion object {
    init {
      // Frame processor plugins will be registered here
      // Example:
      // FrameProcessorPluginRegistry.addFrameProcessorPlugin("scanTextV2") { proxy, options ->
      //   TextRecognitionPlugin(proxy, options)
      // }
    }
  }

  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
    return listOf(
      // Native modules will be added here
      // Example:
      // StaticTextRecognitionModule(reactContext),
      // StaticBarcodeScannerModule(reactContext),
    )
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    return emptyList()
  }
}
