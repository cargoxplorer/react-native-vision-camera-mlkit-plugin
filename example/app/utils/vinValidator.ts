/**
 * VIN (Vehicle Identification Number) validation and extraction utilities
 */

const VIN_WEIGHTS = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];
const VIN_LENGTH = 17;
const VIN_INVALID_CHARS = /[IOQ]/i;
const VIN_TRANSLITERATION: { [key: string]: number } = {
  A: 1,
  B: 2,
  C: 3,
  D: 4,
  E: 5,
  F: 6,
  G: 7,
  H: 8,
  J: 1,
  K: 2,
  L: 3,
  M: 4,
  N: 5,
  P: 7,
  R: 9,
  S: 2,
  T: 3,
  U: 4,
  V: 5,
  W: 6,
  X: 7,
  Y: 8,
  Z: 9,
};

/**
 * Clean OCR text by removing artifacts and fixing common character confusion
 */
export const cleanOCRText = (text: string): string => {
  return text
    .replace(/[.\-_•·∙]/g, '') // Remove punctuation artifacts
    .replace(/[Oo]/g, '0') // Fix O/o confusion
    .replace(/[Il]/g, '1') // Fix I/l confusion
    .toUpperCase();
};

/**
 * Validate VIN checksum using the official algorithm
 * Position 9 contains the check digit
 */
export const validateVINChecksum = (vin: string): boolean => {
  if (vin.length !== VIN_LENGTH) {
    return false;
  }

  let sum = 0;
  for (let i = 0; i < VIN_LENGTH; i++) {
    const char = vin[i];
    const value = isNaN(Number(char))
      ? VIN_TRANSLITERATION[char] || 0
      : Number(char);
    sum += value * VIN_WEIGHTS[i];
  }

  const checkDigit = sum % 11;
  const expectedCheckDigit = checkDigit === 10 ? 'X' : String(checkDigit);
  return vin[8] === expectedCheckDigit;
};

/**
 * Check if VIN contains invalid characters (I, O, Q)
 */
export const hasInvalidChars = (vin: string): boolean => {
  return VIN_INVALID_CHARS.test(vin);
};

/**
 * Check if VIN has proper character distribution (letters vs numbers)
 */
export const hasValidDistribution = (vin: string): boolean => {
  const letterCount = (vin.match(/[A-Z]/g) || []).length;
  const numberCount = (vin.match(/[0-9]/g) || []).length;
  return letterCount >= 5 && numberCount >= 3;
};

/**
 * Check if VIN contains overly repetitive sequences
 */
export const hasExcessiveRepetition = (vin: string): boolean => {
  return /(.)\1{5,}/.test(vin);
};

/**
 * Comprehensive VIN validation
 * Checks format, distribution, repetition, and checksum
 */
export const isValidVIN = (vin: string): boolean => {
  if (vin.length !== VIN_LENGTH) {
    return false;
  }

  return (
    !hasInvalidChars(vin) &&
    hasValidDistribution(vin) &&
    !hasExcessiveRepetition(vin) &&
    validateVINChecksum(vin)
  );
};

/**
 * Extract VIN from OCR text
 * Processes line by line to avoid concatenating unrelated text blocks
 * Removes spaces within lines to handle OCR artifacts
 */
export const extractVINFromText = (text: string): string | null => {
  const cleanedText = cleanOCRText(text);
  const lines = cleanedText.split(/[\n\r]+/);
  const vinRegex = /[A-HJ-NPR-Z0-9]{17}/g;

  for (const line of lines) {
    const lineWithoutSpaces = line.replace(/\s+/g, '');
    const matches = lineWithoutSpaces.match(vinRegex);

    if (matches) {
      for (const match of matches) {
        if (isValidVIN(match)) {
          return match;
        }
      }
    }
  }

  return null;
};
