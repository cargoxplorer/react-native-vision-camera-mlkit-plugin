/**
 * Unit tests for Barcode Scanning
 * Following TDD: Tests written BEFORE implementation
 */

import { createBarcodeScannerPlugin } from '../barcodeScanning';
import { BarcodeFormat } from '../types';
import { mockVisionCameraProxy, mockPlugin } from './__mocks__/VisionCameraProxy';

describe('createBarcodeScannerPlugin', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockVisionCameraProxy.initFrameProcessorPlugin.mockReturnValue(mockPlugin);
  });

  describe('plugin initialization', () => {
    it('should create plugin with default options', () => {
      const plugin = createBarcodeScannerPlugin();

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        {}
      );
      expect(plugin).toBeDefined();
      expect(plugin.scanBarcode).toBeDefined();
    });

    it('should create plugin with no format restrictions', () => {
      const plugin = createBarcodeScannerPlugin();

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        {}
      );
      expect(plugin).toBeDefined();
    });

    it('should create plugin with specific barcode formats', () => {
      createBarcodeScannerPlugin({
        formats: [BarcodeFormat.QR_CODE, BarcodeFormat.EAN_13],
      });

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        { formats: ['qrcode', 'ean13'] }
      );
    });

    it('should create plugin with single format', () => {
      createBarcodeScannerPlugin({
        formats: [BarcodeFormat.QR_CODE],
      });

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        { formats: ['qrcode'] }
      );
    });

    it('should create plugin with all 1D formats', () => {
      const formats = [
        BarcodeFormat.CODABAR,
        BarcodeFormat.CODE_39,
        BarcodeFormat.CODE_93,
        BarcodeFormat.CODE_128,
        BarcodeFormat.EAN_8,
        BarcodeFormat.EAN_13,
        BarcodeFormat.ITF,
        BarcodeFormat.UPC_A,
        BarcodeFormat.UPC_E,
      ];

      createBarcodeScannerPlugin({ formats });

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        {
          formats: [
            'codabar',
            'code39',
            'code93',
            'code128',
            'ean8',
            'ean13',
            'itf',
            'upca',
            'upce',
          ],
        }
      );
    });

    it('should create plugin with all 2D formats', () => {
      const formats = [
        BarcodeFormat.AZTEC,
        BarcodeFormat.DATA_MATRIX,
        BarcodeFormat.PDF417,
        BarcodeFormat.QR_CODE,
      ];

      createBarcodeScannerPlugin({ formats });

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        { formats: ['aztec', 'datamatrix', 'pdf417', 'qrcode'] }
      );
    });
  });

  describe('error handling', () => {
    it('should throw error when plugin initialization fails', () => {
      mockVisionCameraProxy.initFrameProcessorPlugin.mockReturnValue(null as any);

      expect(() => createBarcodeScannerPlugin()).toThrow(
        "Failed to initialize Barcode Scanner plugin. Make sure 'react-native-vision-camera-ml-kit' is properly installed and linked."
      );
    });

    it('should throw error when plugin is undefined', () => {
      mockVisionCameraProxy.initFrameProcessorPlugin.mockReturnValue(undefined as any);

      expect(() => createBarcodeScannerPlugin()).toThrow();
    });
  });

  describe('scanBarcode function', () => {
    it('should return a scanBarcode function', () => {
      const plugin = createBarcodeScannerPlugin();

      expect(typeof plugin.scanBarcode).toBe('function');
    });

    it('should call native plugin with frame', () => {
      const plugin = createBarcodeScannerPlugin();
      const mockFrame = { width: 1920, height: 1080 } as any;

      mockPlugin.call.mockReturnValue({
        barcodes: [
          {
            rawValue: 'https://example.com',
            displayValue: 'https://example.com',
            format: 'qrcode',
            valueType: 'url',
          },
        ],
      });

      const result = plugin.scanBarcode(mockFrame);

      expect(mockPlugin.call).toHaveBeenCalledWith(mockFrame);
      expect(result).toBeDefined();
      expect(result?.barcodes).toHaveLength(1);
    });

    it('should handle null result from native', () => {
      const plugin = createBarcodeScannerPlugin();
      const mockFrame = { width: 1920, height: 1080 } as any;

      mockPlugin.call.mockReturnValue(null);

      const result = plugin.scanBarcode(mockFrame);

      expect(result).toBeNull();
    });

    it('should handle empty barcodes array', () => {
      const plugin = createBarcodeScannerPlugin();
      const mockFrame = { width: 1920, height: 1080 } as any;

      mockPlugin.call.mockReturnValue({
        barcodes: [],
      });

      const result = plugin.scanBarcode(mockFrame);

      expect(result).toEqual({
        barcodes: [],
      });
    });

    it('should return QR code result', () => {
      const plugin = createBarcodeScannerPlugin();
      const mockFrame = { width: 1920, height: 1080 } as any;

      const mockResult = {
        barcodes: [
          {
            rawValue: 'https://example.com',
            displayValue: 'https://example.com',
            format: 'qrcode',
            valueType: 'url',
            frame: { x: 100, y: 200, width: 300, height: 300 },
            cornerPoints: [
              { x: 100, y: 200 },
              { x: 400, y: 200 },
              { x: 400, y: 500 },
              { x: 100, y: 500 },
            ],
            url: 'https://example.com',
          },
        ],
      };

      mockPlugin.call.mockReturnValue(mockResult);

      const result = plugin.scanBarcode(mockFrame);

      expect(result).toEqual(mockResult);
      expect(result?.barcodes[0].valueType).toBe('url');
      expect(result?.barcodes[0].url).toBe('https://example.com');
    });

    it('should handle multiple barcodes', () => {
      const plugin = createBarcodeScannerPlugin();
      const mockFrame = { width: 1920, height: 1080 } as any;

      const mockResult = {
        barcodes: [
          {
            rawValue: '1234567890123',
            displayValue: '1234567890123',
            format: 'ean13',
            valueType: 'text',
          },
          {
            rawValue: '9876543210987',
            displayValue: '9876543210987',
            format: 'ean13',
            valueType: 'text',
          },
        ],
      };

      mockPlugin.call.mockReturnValue(mockResult);

      const result = plugin.scanBarcode(mockFrame);

      expect(result?.barcodes).toHaveLength(2);
      expect(result?.barcodes[0].format).toBe('ean13');
      expect(result?.barcodes[1].format).toBe('ean13');
    });

    it('should handle WiFi barcode', () => {
      const plugin = createBarcodeScannerPlugin();
      const mockFrame = { width: 1920, height: 1080 } as any;

      const mockResult = {
        barcodes: [
          {
            rawValue: 'WIFI:S:MyNetwork;T:WPA;P:password123;;',
            displayValue: 'WiFi Network',
            format: 'qrcode',
            valueType: 'wifi',
            wifi: {
              ssid: 'MyNetwork',
              password: 'password123',
              encryptionType: 'wpa',
            },
          },
        ],
      };

      mockPlugin.call.mockReturnValue(mockResult);

      const result = plugin.scanBarcode(mockFrame);

      expect(result?.barcodes[0].valueType).toBe('wifi');
      expect(result?.barcodes[0].wifi?.ssid).toBe('MyNetwork');
      expect(result?.barcodes[0].wifi?.password).toBe('password123');
    });

    it('should handle contact barcode', () => {
      const plugin = createBarcodeScannerPlugin();
      const mockFrame = { width: 1920, height: 1080 } as any;

      const mockResult = {
        barcodes: [
          {
            rawValue: 'BEGIN:VCARD...',
            displayValue: 'John Doe',
            format: 'qrcode',
            valueType: 'contact',
            contact: {
              name: 'John Doe',
              organization: 'Acme Corp',
              phones: ['+1234567890'],
              emails: ['john@example.com'],
            },
          },
        ],
      };

      mockPlugin.call.mockReturnValue(mockResult);

      const result = plugin.scanBarcode(mockFrame);

      expect(result?.barcodes[0].valueType).toBe('contact');
      expect(result?.barcodes[0].contact?.name).toBe('John Doe');
    });
  });

  describe('inverted barcode detection', () => {
    it('should pass detectInvertedBarcodes option to native', () => {
      createBarcodeScannerPlugin({
        detectInvertedBarcodes: true,
      });

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        { detectInvertedBarcodes: true }
      );
    });

    it('should handle detectInvertedBarcodes with formats', () => {
      createBarcodeScannerPlugin({
        formats: [BarcodeFormat.QR_CODE],
        detectInvertedBarcodes: true,
      });

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        { formats: ['qrcode'], detectInvertedBarcodes: true }
      );
    });

    it('should default detectInvertedBarcodes to false', () => {
      createBarcodeScannerPlugin();

      expect(mockVisionCameraProxy.initFrameProcessorPlugin).toHaveBeenCalledWith(
        'scanBarcode',
        {}
      );
    });

    it('should detect inverted barcode results', () => {
      const plugin = createBarcodeScannerPlugin({
        detectInvertedBarcodes: true,
      });
      const mockFrame = { width: 1920, height: 1080 } as any;

      const mockResult = {
        barcodes: [
          {
            rawValue: 'https://inverted.example.com',
            displayValue: 'https://inverted.example.com',
            format: 'qrcode',
            valueType: 'url',
            url: 'https://inverted.example.com',
          },
        ],
      };

      mockPlugin.call.mockReturnValue(mockResult);

      const result = plugin.scanBarcode(mockFrame);

      expect(result).toEqual(mockResult);
      expect(result?.barcodes[0].url).toBe('https://inverted.example.com');
    });
  });
});
