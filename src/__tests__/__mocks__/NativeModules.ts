/**
 * Mock for React Native NativeModules
 */

export const mockNativeModule = {
  processImage: jest.fn(),
  scanBarcode: jest.fn(),
  recognizeText: jest.fn(),
};

export const NativeModules = {
  StaticTextRecognitionModule: mockNativeModule,
  StaticBarcodeScannerModule: mockNativeModule,
  StaticDocumentScannerModule: mockNativeModule,
};
