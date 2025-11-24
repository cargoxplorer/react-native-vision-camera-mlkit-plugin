import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraFormat,
  useFrameProcessor,
  runAtTargetFps,
  runAsync,
} from 'react-native-vision-camera';
import { Worklets } from 'react-native-worklets-core';
import {
  useBarcodeScanner,
  useTextRecognition,
  TextRecognitionScript,
  BarcodeFormat,
  type Barcode,
  type TextRecognitionResult,
} from 'react-native-vision-camera-ml-kit';
import { useAppLifecycle } from './utils/useAppLifecycle';
import { extractVINFromText } from './utils/vinValidator';

// VIN is 17 characters long
const VIN_LENGTH = 17;
const BARCODE_CONFIRMATION_THRESHOLD = 3; // Need 3 matching barcode reads
const OCR_CONFIRMATION_THRESHOLD = 3; // Need 3 matching OCR results to confirm
const MATCH_EXPIRY_MS = 5000; // Remove matches not seen in last 5 seconds

interface VINMatch {
  vin: string;
  count: number;
  lastDetected: number;
}

export default function VINScannerScreen() {
  const [hasPermission, setHasPermission] = useState(false);
  const [isActive, setIsActive] = useState(true);
  const [barcodeMatches, setBarcodeMatches] = useState<Map<string, VINMatch>>(
    new Map()
  );
  const [ocrMatches, setOcrMatches] = useState<Map<string, VINMatch>>(
    new Map()
  );
  const [confirmedVIN, setConfirmedVIN] = useState<string | null>(null);
  const [scanMode, setScanMode] = useState<'all' | 'barcode' | 'ocr'>('all');
  const [exposure, setExposure] = useState(0); // Range: -2.0 to 2.0

  const device = useCameraDevice('back');
  const format = useCameraFormat(
    device,
    React.useMemo(() => [{ photoHdr: true }, { videoHdr: true }], [])
  );

  // Barcode scanner configuration
  // VINs are typically encoded in CODE_128 or CODE_39 formats
  const barcodeOptions = React.useMemo(
    () => ({
      formats:
        scanMode === 'ocr'
          ? []
          : [BarcodeFormat.CODE_128, BarcodeFormat.CODE_39],
      detectInvertedBarcodes: true, // Enable inverted barcode detection
    }),
    [scanMode]
  );
  const { scanBarcode } = useBarcodeScanner(barcodeOptions);

  // Text recognition configuration
  const textOptions = React.useMemo(
    () => ({ language: TextRecognitionScript.LATIN }),
    []
  );
  const { scanText } = useTextRecognition(textOptions);

  React.useEffect(() => {
    (async () => {
      const status = await Camera.requestCameraPermission();
      setHasPermission(status === 'granted');
    })();
  }, []);

  // Handle app lifecycle
  useAppLifecycle(setIsActive);

  // Process barcode results
  const onBarcodesDetected = Worklets.createRunOnJS((detected: Barcode[]) => {
    if (scanMode === 'ocr' || detected.length === 0) return;

    for (const barcode of detected) {
      if (barcode.displayValue && barcode.displayValue.length === VIN_LENGTH) {
        const vin = barcode.displayValue.toUpperCase();
        // Validate VIN format (no I, O, Q)
        if (!/[IOQ]/i.test(vin)) {
          setBarcodeMatches((prev) => {
            const newMatches = new Map(prev);
            const now = Date.now();

            // Clean up stale entries
            for (const [key, value] of newMatches.entries()) {
              if (now - value.lastDetected > MATCH_EXPIRY_MS) {
                newMatches.delete(key);
              }
            }

            const match = newMatches.get(vin);

            if (match) {
              // Update existing match
              newMatches.set(vin, {
                ...match,
                count: match.count + 1,
                lastDetected: now,
              });
            } else {
              // Add new match
              newMatches.set(vin, {
                vin,
                count: 1,
                lastDetected: now,
              });
            }

            // Check if we've reached barcode confirmation threshold
            const updated = newMatches.get(vin);
            if (updated && updated.count >= BARCODE_CONFIRMATION_THRESHOLD) {
              setConfirmedVIN(vin);
            }

            return newMatches;
          });
        }
      }
    }
  });

  // Process OCR results
  const onTextDetected = Worklets.createRunOnJS(
    (textResult: TextRecognitionResult | null) => {
      if (scanMode === 'barcode' || !textResult) return;

      const fullText = textResult.text || '';
      const vin = extractVINFromText(fullText);

      if (vin && vin.length === VIN_LENGTH) {
        setOcrMatches((prev) => {
          const newMatches = new Map(prev);
          const now = Date.now();

          // Clean up stale entries
          for (const [key, value] of newMatches.entries()) {
            if (now - value.lastDetected > MATCH_EXPIRY_MS) {
              newMatches.delete(key);
            }
          }

          const match = newMatches.get(vin);

          if (match) {
            // Update existing match
            newMatches.set(vin, {
              ...match,
              count: match.count + 1,
              lastDetected: now,
            });
          } else {
            // Add new match
            newMatches.set(vin, {
              vin,
              count: 1,
              lastDetected: now,
            });
          }

          // Check if we've reached confirmation threshold
          const updated = newMatches.get(vin);
          if (updated && updated.count >= OCR_CONFIRMATION_THRESHOLD) {
            setConfirmedVIN(vin);
          }

          return newMatches;
        });
      }
    }
  );

  // Combined frame processor for all/barcode/ocr modes
  const combinedFrameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';

      // Barcode detection (for 'barcode' and 'all' modes)
      if (scanMode !== 'ocr') {
        runAtTargetFps(3, () => {
          'worklet';
          // Run async to prevent blocking the camera thread
          runAsync(frame, () => {
            'worklet';
            try {
              const result = scanBarcode(frame);
              if (result?.barcodes && result.barcodes.length > 0) {
                onBarcodesDetected(result.barcodes);
              }
            } catch (error) {
              console.error('Barcode scanning error:', error);
            }
          });
        });
      }

      // Text recognition (for 'ocr' and 'all' modes)
      if (scanMode !== 'barcode') {
        runAtTargetFps(1, () => {
          'worklet';
          // Run async to prevent blocking the camera thread
          runAsync(frame, () => {
            'worklet';
            try {
              const result = scanText(frame);
              onTextDetected(result);
            } catch (error) {
              console.error('Text recognition error:', error);
            }
          });
        });
      }
    },
    [scanBarcode, scanText, scanMode]
  );

  const handleReset = () => {
    setBarcodeMatches(new Map());
    setOcrMatches(new Map());
    setConfirmedVIN(null);
  };

  const handleConfirm = () => {
    if (confirmedVIN) {
      Alert.alert('VIN Confirmed', `Confirmed VIN: ${confirmedVIN}`, [
        { text: 'Copy', onPress: () => console.log('Copy:', confirmedVIN) },
        { text: 'OK', onPress: handleReset },
      ]);
    }
  };

  if (!hasPermission) {
    return (
      <View style={styles.container}>
        <Text>Camera permission required</Text>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={styles.container}>
        <Text>No camera device found</Text>
      </View>
    );
  }

  const barcodeMatchesArray = Array.from(barcodeMatches.values())
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  const ocrMatchesArray = Array.from(ocrMatches.values())
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  const topBarcodeMatch = barcodeMatchesArray[0];
  const topOCRMatch = ocrMatchesArray[0];
  const isConfirmed = confirmedVIN !== null;

  return (
    <View style={styles.container}>
      <View style={styles.cameraContainer}>
        <Camera
          style={StyleSheet.absoluteFill}
          device={device}
          isActive={isActive}
          format={format}
          videoHdr={format?.supportsVideoHdr ?? false}
          photoHdr={format?.supportsPhotoHdr ?? false}
          frameProcessor={combinedFrameProcessor}
          pixelFormat="yuv"
          exposure={exposure}
        />

        {/* Overlay with status */}
        <View style={styles.overlay}>
          <View
            style={[
              styles.statusBadge,
              isConfirmed && styles.statusBadgeConfirmed,
            ]}
          >
            <Text
              style={[
                styles.statusText,
                isConfirmed && styles.statusTextConfirmed,
              ]}
            >
              {isConfirmed ? '✓ VIN CONFIRMED' : 'Scanning...'}
            </Text>
          </View>

          {confirmedVIN && (
            <View style={styles.vinDisplay}>
              <Text style={styles.vinLabel}>CONFIRMED VIN:</Text>
              <Text style={styles.vinValue}>{confirmedVIN}</Text>
            </View>
          )}

          {topBarcodeMatch && !confirmedVIN && (
            <View style={styles.vinDisplay}>
              <Text style={styles.vinLabel}>BARCODE VIN:</Text>
              <Text style={styles.vinValue}>{topBarcodeMatch.vin}</Text>
              <Text style={styles.ocrCount}>
                {topBarcodeMatch.count}/{BARCODE_CONFIRMATION_THRESHOLD}
              </Text>
            </View>
          )}

          {topOCRMatch && !confirmedVIN && (
            <View style={styles.ocrDisplay}>
              <Text style={styles.ocrLabel}>OCR MATCH:</Text>
              <Text style={styles.ocrValue}>{topOCRMatch.vin}</Text>
              <Text style={styles.ocrCount}>
                {topOCRMatch.count}/{OCR_CONFIRMATION_THRESHOLD}
              </Text>
            </View>
          )}
        </View>
      </View>

      {/* Controls */}
      <View style={styles.controls}>
        <TouchableOpacity
          style={[
            styles.modeButton,
            scanMode === 'all' && styles.modeButtonActive,
          ]}
          onPress={() => setScanMode('all')}
        >
          <Text
            style={[
              styles.modeButtonText,
              scanMode === 'all' && styles.modeButtonTextActive,
            ]}
          >
            All Modes
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.modeButton,
            scanMode === 'barcode' && styles.modeButtonActive,
          ]}
          onPress={() => setScanMode('barcode')}
        >
          <Text
            style={[
              styles.modeButtonText,
              scanMode === 'barcode' && styles.modeButtonTextActive,
            ]}
          >
            Barcode Only
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.modeButton,
            scanMode === 'ocr' && styles.modeButtonActive,
          ]}
          onPress={() => setScanMode('ocr')}
        >
          <Text
            style={[
              styles.modeButtonText,
              scanMode === 'ocr' && styles.modeButtonTextActive,
            ]}
          >
            OCR Only
          </Text>
        </TouchableOpacity>
      </View>

      {/* Exposure Controls */}
      <View style={styles.exposureContainer}>
        <View style={styles.exposureControls}>
          <TouchableOpacity
            style={styles.exposureButton}
            onPress={() => setExposure(Math.max(-2.0, exposure - 0.5))}
          >
            <Text style={styles.exposureButtonText}>−</Text>
          </TouchableOpacity>

          <View style={styles.exposureDisplay}>
            <Text style={styles.exposureLabel}>Exposure</Text>
            <Text style={styles.exposureValue}>
              {exposure >= 0 ? '+' : ''}
              {exposure.toFixed(1)}
            </Text>
          </View>

          <TouchableOpacity
            style={styles.exposureButton}
            onPress={() => setExposure(Math.min(2.0, exposure + 0.5))}
          >
            <Text style={styles.exposureButtonText}>+</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.resetButtonStyle}
            onPress={() => setExposure(0)}
          >
            <Text style={styles.exposureButtonText}>Reset</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Results */}
      <View style={styles.results}>
        <View style={styles.resultsHeader}>
          <Text style={styles.resultsTitle}>Scan Results</Text>
          {(barcodeMatches.size > 0 || ocrMatches.size > 0) && (
            <TouchableOpacity onPress={handleReset}>
              <Text style={styles.resetButton}>Reset</Text>
            </TouchableOpacity>
          )}
        </View>

        <ScrollView style={styles.resultsScroll}>
          {confirmedVIN ? (
            <View style={styles.confirmedSection}>
              <Text style={styles.confirmedTitle}>✓ VIN Confirmed</Text>
              <Text style={styles.confirmedVin}>{confirmedVIN}</Text>
              <TouchableOpacity
                style={styles.actionButton}
                onPress={handleConfirm}
              >
                <Text style={styles.actionButtonText}>Done</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <>
              {barcodeMatchesArray.length > 0 && (
                <View style={styles.section}>
                  <Text style={styles.sectionTitle}>
                    Barcode Matches ({barcodeMatches.size})
                  </Text>
                  {barcodeMatchesArray.map((match) => (
                    <View key={match.vin} style={styles.matchCard}>
                      <View style={styles.matchHeader}>
                        <Text style={styles.matchVin}>{match.vin}</Text>
                        <View
                          style={[
                            styles.matchCount,
                            match.count >= BARCODE_CONFIRMATION_THRESHOLD &&
                              styles.matchCountFull,
                          ]}
                        >
                          <Text style={styles.matchCountText}>
                            {match.count}/{BARCODE_CONFIRMATION_THRESHOLD}
                          </Text>
                        </View>
                      </View>
                      <View style={styles.progressBar}>
                        <View
                          style={[
                            styles.progressFill,
                            {
                              width: `${Math.min(
                                (match.count / BARCODE_CONFIRMATION_THRESHOLD) *
                                  100,
                                100
                              )}%`,
                            },
                          ]}
                        />
                      </View>
                    </View>
                  ))}
                </View>
              )}

              {ocrMatchesArray.length > 0 && (
                <View style={styles.section}>
                  <Text style={styles.sectionTitle}>
                    OCR Matches ({ocrMatches.size})
                  </Text>
                  {ocrMatchesArray.map((match) => (
                    <View key={match.vin} style={styles.matchCard}>
                      <View style={styles.matchHeader}>
                        <Text style={styles.matchVin}>{match.vin}</Text>
                        <View
                          style={[
                            styles.matchCount,
                            match.count >= OCR_CONFIRMATION_THRESHOLD &&
                              styles.matchCountFull,
                          ]}
                        >
                          <Text style={styles.matchCountText}>
                            {match.count}/{OCR_CONFIRMATION_THRESHOLD}
                          </Text>
                        </View>
                      </View>
                      <View style={styles.progressBar}>
                        <View
                          style={[
                            styles.progressFill,
                            {
                              width: `${Math.min(
                                (match.count / OCR_CONFIRMATION_THRESHOLD) *
                                  100,
                                100
                              )}%`,
                            },
                          ]}
                        />
                      </View>
                    </View>
                  ))}
                </View>
              )}

              {barcodeMatches.size === 0 && ocrMatches.size === 0 && (
                <View style={styles.emptyState}>
                  <Text style={styles.emptyStateText}>
                    Position VIN in camera view
                  </Text>
                  <Text style={styles.emptyStateHint}>
                    {scanMode === 'all'
                      ? 'Scan barcode or text'
                      : scanMode === 'barcode'
                        ? 'Scan VIN barcode'
                        : 'Read VIN text with OCR'}
                  </Text>
                </View>
              )}
            </>
          )}
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  cameraContainer: {
    flex: 1.5,
    backgroundColor: '#000',
    position: 'relative',
  },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'space-between',
    padding: 20,
  },
  statusBadge: {
    alignSelf: 'center',
    backgroundColor: 'rgba(255, 152, 0, 0.8)',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  statusBadgeConfirmed: {
    backgroundColor: 'rgba(76, 175, 80, 0.8)',
  },
  statusText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  statusTextConfirmed: {
    color: '#fff',
  },
  vinDisplay: {
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    padding: 16,
    borderRadius: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#4CAF50',
  },
  vinLabel: {
    color: '#4CAF50',
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 4,
  },
  vinValue: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
    letterSpacing: 2,
  },
  ocrDisplay: {
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    padding: 12,
    borderRadius: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#2196F3',
  },
  ocrLabel: {
    color: '#2196F3',
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 4,
  },
  ocrValue: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
    letterSpacing: 2,
    marginBottom: 4,
  },
  ocrCount: {
    color: '#aaa',
    fontSize: 12,
  },
  controls: {
    backgroundColor: '#1a1a1a',
    padding: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 8,
  },
  modeButton: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: '#333',
    alignItems: 'center',
  },
  modeButtonActive: {
    backgroundColor: '#2196F3',
  },
  modeButtonText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  modeButtonTextActive: {
    color: '#fff',
  },
  exposureContainer: {
    backgroundColor: '#1a1a1a',
    borderTopWidth: 1,
    borderTopColor: '#333',
    padding: 12,
  },
  exposureControls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  exposureButton: {
    width: 40,
    height: 40,
    borderRadius: 8,
    backgroundColor: '#2196F3',
    alignItems: 'center',
    justifyContent: 'center',
  },
  exposureButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  exposureDisplay: {
    flex: 1,
    alignItems: 'center',
  },
  exposureLabel: {
    color: '#aaa',
    fontSize: 11,
    fontWeight: '600',
  },
  exposureValue: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
    marginTop: 2,
  },
  resetButtonStyle: {
    width: 'auto',
    paddingHorizontal: 12,
    borderRadius: 8,
    backgroundColor: '#2196F3',
    alignItems: 'center',
    justifyContent: 'center',
    height: 40,
  },
  results: {
    flex: 1,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  resultsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  resultsTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  resetButton: {
    color: '#2196F3',
    fontSize: 14,
    fontWeight: '600',
  },
  resultsScroll: {
    flex: 1,
    paddingHorizontal: 16,
  },
  confirmedSection: {
    marginVertical: 16,
    padding: 16,
    backgroundColor: '#e8f5e9',
    borderRadius: 12,
    borderLeftWidth: 4,
    borderLeftColor: '#4CAF50',
    alignItems: 'center',
  },
  confirmedTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#2e7d32',
    marginBottom: 8,
  },
  confirmedVin: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1b5e20',
    letterSpacing: 2,
    marginBottom: 12,
  },
  actionButton: {
    backgroundColor: '#4CAF50',
    paddingHorizontal: 32,
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: 8,
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  section: {
    marginVertical: 12,
    paddingVertical: 12,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    marginBottom: 8,
  },
  sectionValue: {
    fontSize: 16,
    fontWeight: '500',
    color: '#333',
    letterSpacing: 1,
    marginBottom: 4,
  },
  sectionHint: {
    fontSize: 12,
    color: '#999',
    fontStyle: 'italic',
  },
  matchCard: {
    backgroundColor: '#f9f9f9',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
    borderLeftWidth: 3,
    borderLeftColor: '#2196F3',
  },
  matchHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  matchVin: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    letterSpacing: 1,
  },
  matchCount: {
    backgroundColor: '#fff',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2196F3',
  },
  matchCountFull: {
    backgroundColor: '#4CAF50',
    borderColor: '#4CAF50',
  },
  matchCountText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#2196F3',
  },
  progressBar: {
    height: 6,
    backgroundColor: '#e0e0e0',
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#2196F3',
    borderRadius: 3,
  },
  emptyState: {
    paddingVertical: 32,
    alignItems: 'center',
  },
  emptyStateText: {
    fontSize: 16,
    color: '#999',
    marginBottom: 4,
  },
  emptyStateHint: {
    fontSize: 12,
    color: '#ccc',
  },
});
