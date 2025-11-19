/**
 * Barcode Scanning plugin for react-native-vision-camera-ml-kit
 *
 * Provides on-device barcode scanning with support for:
 * - 1D formats: Codabar, Code 39, Code 93, Code 128, EAN-8, EAN-13, ITF, UPC-A, UPC-E
 * - 2D formats: Aztec, Data Matrix, PDF417, QR Code
 * - Structured data extraction: WiFi, URLs, Contacts, Calendar events, etc.
 *
 * @module barcodeScanning
 */

import { VisionCameraProxy } from 'react-native-vision-camera';
import { useMemo } from 'react';
import { Logger } from './utils/Logger';
import type {
  Frame,
  BarcodeScanningOptions,
  BarcodeScanningPlugin,
  BarcodeScanningResult,
} from './types';

const PLUGIN_NAME = 'scanBarcode';

const LINKING_ERROR = `Failed to initialize Barcode Scanner plugin. Make sure 'react-native-vision-camera-ml-kit' is properly installed and linked.

For more information, visit: https://github.com/yourusername/react-native-vision-camera-ml-kit`;

/**
 * Create a Barcode Scanner frame processor plugin
 *
 * @param options - Configuration options for barcode scanning
 * @returns Barcode scanner plugin with scanBarcode function
 *
 * @example
 * ```ts
 * import { createBarcodeScannerPlugin, BarcodeFormat } from 'react-native-vision-camera-ml-kit';
 *
 * // Scan all barcode formats
 * const plugin = createBarcodeScannerPlugin();
 *
 * // Scan only QR codes
 * const qrPlugin = createBarcodeScannerPlugin({
 *   formats: [BarcodeFormat.QR_CODE]
 * });
 *
 * const frameProcessor = useFrameProcessor((frame) => {
 *   'worklet';
 *   const result = plugin.scanBarcode(frame);
 *   if (result?.barcodes.length > 0) {
 *     console.log('Detected barcodes:', result.barcodes);
 *   }
 * }, [plugin]);
 * ```
 */
export function createBarcodeScannerPlugin(
  options: BarcodeScanningOptions = {}
): BarcodeScanningPlugin {
  Logger.debug(`Creating barcode scanner plugin with options:`, options);

  const startTime = performance.now();

  // Initialize the frame processor plugin
  const plugin = VisionCameraProxy.initFrameProcessorPlugin(PLUGIN_NAME, {
    ...options,
  });

  if (!plugin) {
    Logger.error('Failed to initialize barcode scanner plugin');
    throw new Error(LINKING_ERROR);
  }

  const initTime = performance.now() - startTime;
  Logger.performance('Barcode scanner plugin initialization', initTime);

  return {
    /**
     * Scan barcodes from a camera frame
     *
     * @worklet
     * @param frame - The camera frame to process
     * @returns Scanning result with barcodes array, or null if no barcodes found
     */
    scanBarcode: (frame: Frame): BarcodeScanningResult | null => {
      'worklet';
      try {
        const result = plugin.call(frame) as unknown as BarcodeScanningResult | null;
        return result;
      } catch (e) {
        // Log the error so developers can debug issues
        console.error(
          '[react-native-vision-camera-ml-kit] Barcode scanning error:',
          e instanceof Error ? e.message : String(e)
        );
        // Return null instead of propagating an error from the worklet context
        return null;
      }
    },
  };
}

/**
 * React hook for barcode scanning
 *
 * Creates and memoizes a barcode scanner plugin instance.
 * The plugin is recreated only when options change.
 *
 * @param options - Configuration options for barcode scanning
 * @returns Barcode scanner plugin with scanBarcode function
 *
 * @example
 * ```tsx
 * import { useBarcodeScanner, BarcodeFormat } from 'react-native-vision-camera-ml-kit';
 * import { useFrameProcessor } from 'react-native-vision-camera';
 *
 * function MyComponent() {
 *   const { scanBarcode } = useBarcodeScanner({
 *     formats: [BarcodeFormat.QR_CODE, BarcodeFormat.EAN_13]
 *   });
 *
 *   const frameProcessor = useFrameProcessor((frame) => {
 *     'worklet';
 *     const result = scanBarcode(frame);
 *     // Process result...
 *   }, [scanBarcode]);
 *
 *   return <Camera frameProcessor={frameProcessor} />;
 * }
 * ```
 */
export function useBarcodeScanner(
  options?: BarcodeScanningOptions
): BarcodeScanningPlugin {
  // Extract individual options to stable dependencies
  // This prevents unnecessary re-creation when options object reference changes
  // but the actual option values remain the same
  const formats = options?.formats;
  const detectInvertedBarcodes = options?.detectInvertedBarcodes;

  return useMemo(
    () => createBarcodeScannerPlugin(options),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [formats, detectInvertedBarcodes]
  );
}
