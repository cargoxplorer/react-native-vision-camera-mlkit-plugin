/**
 * Unit tests for useBarcodeScanner hook
 * Following TDD: Tests written BEFORE implementation
 */

import { useBarcodeScanner } from '../barcodeScanning';
import { BarcodeFormat } from '../types';
import { mockVisionCameraProxy, mockPlugin } from './__mocks__/VisionCameraProxy';

// Create a mock state tracker for useMemo
const mockMemoState = {
  memoizedValue: null as any,
  mockLastDeps: [] as any[],
};

jest.mock('react', () => ({
  ...jest.requireActual('react'),
  useMemo: (factory: () => any, deps: any[]) => {
    // Simulate useMemo behavior: only call factory if deps changed
    const depsChanged =
      mockMemoState.mockLastDeps.length === 0 ||
      deps.length !== mockMemoState.mockLastDeps.length ||
      deps.some((dep, i) => dep !== mockMemoState.mockLastDeps[i]);

    if (depsChanged) {
      mockMemoState.memoizedValue = factory();
      mockMemoState.mockLastDeps = deps;
    }
    return mockMemoState.memoizedValue;
  },
}));

describe('useBarcodeScanner', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockVisionCameraProxy.initFrameProcessorPlugin.mockReturnValue(mockPlugin);
    mockMemoState.memoizedValue = null;
    mockMemoState.mockLastDeps = [];
  });

  it('should create barcode scanner plugin', () => {
    const result = useBarcodeScanner();

    expect(result).toBeDefined();
    expect(result.scanBarcode).toBeDefined();
    expect(typeof result.scanBarcode).toBe('function');
  });

  it('should pass options to plugin creator', () => {
    const options = { formats: [BarcodeFormat.QR_CODE] };
    useBarcodeScanner(options);

    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
      'scanBarcode',
      { formats: ['qrcode'] }
    );
  });

  it('should work without options', () => {
    const result = useBarcodeScanner();

    expect(result).toBeDefined();
    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
      'scanBarcode',
      {}
    );
  });

  it('should memoize plugin instance with same options', () => {
    const options = { formats: [BarcodeFormat.QR_CODE] };

    const result1 = useBarcodeScanner(options);
    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledTimes(
      1
    );

    const result2 = useBarcodeScanner(options);
    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledTimes(
      1
    );

    expect(result1).toBe(result2);
  });

  it('should recreate plugin when options change', () => {
    const options1 = { formats: [BarcodeFormat.QR_CODE] };
    const options2 = { formats: [BarcodeFormat.EAN_13] };

    useBarcodeScanner(options1);
    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledTimes(
      1
    );

    // Reset memoization
    mockMemoState.mockLastDeps = [];

    useBarcodeScanner(options2);
    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledTimes(
      2
    );
  });

  it('should recreate plugin when detectInvertedBarcodes changes', () => {
    const options1 = { detectInvertedBarcodes: false };
    const options2 = { detectInvertedBarcodes: true };

    useBarcodeScanner(options1);
    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledTimes(
      1
    );

    // Reset memoization
    mockMemoState.mockLastDeps = [];

    useBarcodeScanner(options2);
    expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledTimes(
      2
    );
  });
});
