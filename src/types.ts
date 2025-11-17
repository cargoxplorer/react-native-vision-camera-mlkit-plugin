/**
 * TypeScript type definitions for react-native-vision-camera-ml-kit
 */

// Re-export Frame type from react-native-vision-camera
export type { Frame } from 'react-native-vision-camera';

// =============================================================================
// Common Types
// =============================================================================

/**
 * Point representing a coordinate in 2D space
 */
export interface Point {
  x: number;
  y: number;
}

/**
 * Rectangle frame with position and dimensions
 */
export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * Corner points of a detected element (typically 4 points)
 */
export type CornerPoints = Point[];

// =============================================================================
// Text Recognition v2 Types
// =============================================================================

/**
 * Supported text recognition languages/scripts
 */
export enum TextRecognitionScript {
  LATIN = 'latin',
  CHINESE = 'chinese',
  DEVANAGARI = 'devanagari',
  JAPANESE = 'japanese',
  KOREAN = 'korean',
}

/**
 * Options for text recognition
 */
export interface TextRecognitionOptions {
  /**
   * Script/language to use for text recognition
   * @default 'latin'
   */
  language?: TextRecognitionScript | string;
}

/**
 * A single recognized symbol (character)
 */
export interface TextSymbol {
  /**
   * The recognized text for this symbol
   */
  text: string;

  /**
   * Bounding box of the symbol
   */
  frame: Rect;

  /**
   * Corner points of the symbol
   */
  cornerPoints: CornerPoints;

  /**
   * Confidence score (0-1)
   */
  confidence?: number;
}

/**
 * A recognized text element (word)
 */
export interface TextElement {
  /**
   * The recognized text for this element
   */
  text: string;

  /**
   * Bounding box of the element
   */
  frame: Rect;

  /**
   * Corner points of the element
   */
  cornerPoints: CornerPoints;

  /**
   * Individual symbols in this element
   */
  symbols: TextSymbol[];

  /**
   * Confidence score (0-1)
   */
  confidence?: number;

  /**
   * Detected language code (e.g., 'en', 'zh')
   */
  recognizedLanguage?: string;
}

/**
 * A line of recognized text
 */
export interface TextLine {
  /**
   * The complete text of this line
   */
  text: string;

  /**
   * Bounding box of the line
   */
  frame: Rect;

  /**
   * Corner points of the line
   */
  cornerPoints: CornerPoints;

  /**
   * Elements (words) in this line
   */
  elements: TextElement[];

  /**
   * Confidence score (0-1)
   */
  confidence?: number;

  /**
   * Detected language code (e.g., 'en', 'zh')
   */
  recognizedLanguage?: string;
}

/**
 * A block of recognized text (paragraph or column)
 */
export interface TextBlock {
  /**
   * The complete text of this block
   */
  text: string;

  /**
   * Bounding box of the block
   */
  frame: Rect;

  /**
   * Corner points of the block
   */
  cornerPoints: CornerPoints;

  /**
   * Lines in this block
   */
  lines: TextLine[];

  /**
   * Confidence score (0-1)
   */
  confidence?: number;

  /**
   * Detected language code (e.g., 'en', 'zh')
   */
  recognizedLanguage?: string;
}

/**
 * Result from text recognition
 */
export interface TextRecognitionResult {
  /**
   * The complete recognized text
   */
  text: string;

  /**
   * Blocks of text found in the image
   */
  blocks: TextBlock[];
}

// =============================================================================
// Barcode Scanning Types
// =============================================================================

/**
 * Supported barcode formats
 */
export enum BarcodeFormat {
  // 1D formats
  CODABAR = 'codabar',
  CODE_39 = 'code39',
  CODE_93 = 'code93',
  CODE_128 = 'code128',
  EAN_8 = 'ean8',
  EAN_13 = 'ean13',
  ITF = 'itf',
  UPC_A = 'upca',
  UPC_E = 'upce',

  // 2D formats
  AZTEC = 'aztec',
  DATA_MATRIX = 'dataMatrix',
  PDF417 = 'pdf417',
  QR_CODE = 'qrCode',

  // Unknown
  UNKNOWN = 'unknown',
}

/**
 * Value type for barcode data
 */
export enum BarcodeValueType {
  TEXT = 'text',
  URL = 'url',
  EMAIL = 'email',
  PHONE = 'phone',
  SMS = 'sms',
  WIFI = 'wifi',
  GEO = 'geo',
  CONTACT = 'contact',
  CALENDAR_EVENT = 'calendarEvent',
  DRIVER_LICENSE = 'driverLicense',
  UNKNOWN = 'unknown',
}

/**
 * WiFi network information from barcode
 */
export interface BarcodeWifi {
  ssid: string;
  password: string;
  encryptionType: 'open' | 'wpa' | 'wep';
}

/**
 * Contact information from barcode
 */
export interface BarcodeContact {
  name?: string;
  organization?: string;
  phones?: string[];
  emails?: string[];
  urls?: string[];
  addresses?: string[];
}

/**
 * Calendar event from barcode
 */
export interface BarcodeCalendarEvent {
  summary?: string;
  description?: string;
  location?: string;
  start?: string;
  end?: string;
}

/**
 * Driver license information from barcode
 */
export interface BarcodeDriverLicense {
  documentType?: string;
  firstName?: string;
  lastName?: string;
  gender?: string;
  addressStreet?: string;
  addressCity?: string;
  addressState?: string;
  addressZip?: string;
  licenseNumber?: string;
  issueDate?: string;
  expiryDate?: string;
  birthDate?: string;
  issuingCountry?: string;
}

/**
 * Options for barcode scanning
 */
export interface BarcodeScanningOptions {
  /**
   * Limit scanning to specific barcode formats
   * If not specified, all formats are scanned
   */
  formats?: BarcodeFormat[];
}

/**
 * A single detected barcode
 */
export interface Barcode {
  /**
   * The raw value of the barcode
   */
  rawValue: string;

  /**
   * Display value (may be formatted)
   */
  displayValue: string;

  /**
   * Format of the barcode
   */
  format: BarcodeFormat;

  /**
   * Value type of the barcode
   */
  valueType: BarcodeValueType;

  /**
   * Bounding box of the barcode
   */
  frame: Rect;

  /**
   * Corner points of the barcode
   */
  cornerPoints: CornerPoints;

  /**
   * WiFi information (if valueType is WIFI)
   */
  wifi?: BarcodeWifi;

  /**
   * Contact information (if valueType is CONTACT)
   */
  contact?: BarcodeContact;

  /**
   * Calendar event (if valueType is CALENDAR_EVENT)
   */
  calendarEvent?: BarcodeCalendarEvent;

  /**
   * Driver license info (if valueType is DRIVER_LICENSE)
   */
  driverLicense?: BarcodeDriverLicense;

  /**
   * URL (if valueType is URL)
   */
  url?: string;

  /**
   * Email (if valueType is EMAIL)
   */
  email?: string;

  /**
   * Phone number (if valueType is PHONE)
   */
  phone?: string;

  /**
   * SMS info (if valueType is SMS)
   */
  sms?: {
    phoneNumber: string;
    message: string;
  };

  /**
   * Geo coordinates (if valueType is GEO)
   */
  geo?: {
    latitude: number;
    longitude: number;
  };
}

/**
 * Result from barcode scanning
 * Can contain up to 10 barcodes per scan
 */
export interface BarcodeScanningResult {
  /**
   * Detected barcodes
   */
  barcodes: Barcode[];
}

// =============================================================================
// Document Scanner Types (Android Only)
// =============================================================================

/**
 * Document scanner modes
 */
export enum DocumentScannerMode {
  /**
   * Base mode: crop, rotate, reorder
   */
  BASE = 'base',

  /**
   * Base mode + image filters
   */
  BASE_WITH_FILTER = 'baseWithFilter',

  /**
   * Full mode: base + ML-powered cleaning (default)
   */
  FULL = 'full',
}

/**
 * Options for document scanner
 */
export interface DocumentScannerOptions {
  /**
   * Scanner mode
   * @default 'full'
   */
  mode?: DocumentScannerMode;

  /**
   * Maximum number of pages to scan
   * @default 1
   */
  pageLimit?: number;

  /**
   * Enable importing from gallery
   * @default true
   */
  galleryImportEnabled?: boolean;
}

/**
 * A scanned document page
 */
export interface DocumentPage {
  /**
   * URI of the processed document image
   */
  uri: string;

  /**
   * Page number (1-indexed)
   */
  pageNumber: number;

  /**
   * Original dimensions
   */
  originalSize?: {
    width: number;
    height: number;
  };

  /**
   * Processed dimensions
   */
  processedSize?: {
    width: number;
    height: number;
  };
}

/**
 * Result from document scanning
 */
export interface DocumentScanningResult {
  /**
   * Scanned pages
   */
  pages: DocumentPage[];

  /**
   * Total number of pages scanned
   */
  pageCount: number;
}

// =============================================================================
// Plugin Types
// =============================================================================

/**
 * Text recognition plugin interface
 */
export interface TextRecognitionPlugin {
  /**
   * Scan text from a camera frame
   * Must be called from a worklet
   */
  scanText: (frame: Frame) => TextRecognitionResult | null;
}

/**
 * Barcode scanning plugin interface
 */
export interface BarcodeScanningPlugin {
  /**
   * Scan barcodes from a camera frame
   * Must be called from a worklet
   */
  scanBarcode: (frame: Frame) => BarcodeScanningResult | null;
}

/**
 * Document scanner plugin interface
 */
export interface DocumentScannerPlugin {
  /**
   * Scan document from a camera frame
   * Must be called from a worklet
   */
  scanDocument: (frame: Frame) => DocumentScanningResult | null;
}

// =============================================================================
// Static Image Processing Types
// =============================================================================

/**
 * Options for static image processing
 */
export interface StaticImageOptions {
  /**
   * URI of the image to process (file://, content://, etc.)
   */
  uri: string;

  /**
   * Image orientation (0, 90, 180, 270)
   * @default 0
   */
  orientation?: number;
}

// =============================================================================
// Export Logger Types
// =============================================================================

export { LogLevel } from './utils/Logger';
