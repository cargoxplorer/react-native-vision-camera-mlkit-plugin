import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
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
  BarcodeFormat,
  type Barcode,
} from 'react-native-vision-camera-ml-kit';
import { useAppLifecycle } from './utils/useAppLifecycle';

export default function BarcodeScannerScreen() {
  const [hasPermission, setHasPermission] = useState(false);
  const [barcodes, setBarcodes] = useState<Barcode[]>([]);
  const [filterQROnly, setFilterQROnly] = useState(false);
  const [detectInverted, setDetectInverted] = useState(false);
  const [tryRotations, setTryRotations] = useState(true);
  const [isActive, setIsActive] = useState(true);

  const device = useCameraDevice('back');
  const format = useCameraFormat(
    device,
    React.useMemo(() => [{ photoHdr: true }, { videoHdr: true }], [])
  );
  const barcodeOptions = React.useMemo(
    () => ({
      formats: filterQROnly ? [BarcodeFormat.QR_CODE] : undefined,
      detectInvertedBarcodes: detectInverted,
      tryRotations: tryRotations,
    }),
    [filterQROnly, detectInverted, tryRotations]
  );
  const { scanBarcode } = useBarcodeScanner(barcodeOptions);

  React.useEffect(() => {
    (async () => {
      const status = await Camera.requestCameraPermission();
      setHasPermission(status === 'granted');
    })();
  }, []);

  // Handle app lifecycle - pause camera when app goes to background
  useAppLifecycle(setIsActive);

  const onBarcodesDetected = Worklets.createRunOnJS((detected: Barcode[]) => {
    // Avoid unnecessary re-renders when barcodes haven't changed
    setBarcodes((prev) => {
      if (prev.length === 0 && detected.length === 0) return prev;
      if (
        prev.length === detected.length &&
        prev.every((b, i) => b.displayValue === detected[i]?.displayValue)
      ) {
        return prev;
      }
      return detected;
    });
  });

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      // Throttle barcode scanning to avoid running on every frame
      runAtTargetFps(3, () => {
        'worklet';
        // Run async to prevent blocking the camera thread (scanning is expensive ~30-120ms)
        runAsync(frame, () => {
          'worklet';
          try {
            const result = scanBarcode(frame);
            // Always notify JS, even when no barcodes were found, so UI can clear
            // old results and react to changes correctly.
            onBarcodesDetected(result?.barcodes || []);
          } catch (error) {
            console.error('Frame processing error:', error);
          }
        });
      });
    },
    [scanBarcode]
  );

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
          frameProcessor={frameProcessor}
          pixelFormat="yuv"
        />

        {barcodes.length > 0 && (
          <View style={styles.overlay}>
            <Text style={styles.overlayText}>
              {barcodes.length} barcode(s) detected
            </Text>
            {barcodes.map((barcode, index) => (
              <Text key={index} style={styles.overlayBarcode}>
                {barcode.format}: {barcode.displayValue.substring(0, 30)}
                {barcode.displayValue.length > 30 ? '...' : ''}
              </Text>
            ))}
          </View>
        )}
      </View>

      <View style={styles.controls}>
        <TouchableOpacity
          style={[
            styles.filterButton,
            filterQROnly && styles.filterButtonActive,
          ]}
          onPress={() => setFilterQROnly(!filterQROnly)}
        >
          <Text
            style={[
              styles.filterButtonText,
              filterQROnly && styles.filterButtonTextActive,
            ]}
          >
            {filterQROnly ? 'QR Only ✓' : 'All Formats'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.filterButton,
            detectInverted && styles.filterButtonActive,
          ]}
          onPress={() => setDetectInverted(!detectInverted)}
        >
          <Text
            style={[
              styles.filterButtonText,
              detectInverted && styles.filterButtonTextActive,
            ]}
          >
            {detectInverted ? 'Inverted ✓' : 'Normal Only'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.filterButton,
            tryRotations && styles.filterButtonActive,
          ]}
          onPress={() => setTryRotations(!tryRotations)}
        >
          <Text
            style={[
              styles.filterButtonText,
              tryRotations && styles.filterButtonTextActive,
            ]}
          >
            {tryRotations ? 'Rotations ✓' : '0° Only'}
          </Text>
        </TouchableOpacity>
      </View>

      <View style={styles.results}>
        <Text style={styles.resultsTitle}>Barcode Details:</Text>
        <ScrollView style={styles.resultsScroll}>
          {barcodes.length > 0 ? (
            barcodes.map((barcode, index) => (
              <View key={index} style={styles.barcodeCard}>
                <Text style={styles.barcodeFormat}>
                  {barcode.format.toUpperCase()}
                </Text>
                <Text style={styles.barcodeValue}>{barcode.displayValue}</Text>
                <Text style={styles.barcodeType}>
                  Type: {barcode.valueType}
                </Text>

                {barcode.wifi && (
                  <View style={styles.structuredData}>
                    <Text style={styles.structuredDataTitle}>WiFi:</Text>
                    <Text style={styles.structuredDataText}>
                      SSID: {barcode.wifi.ssid}
                    </Text>
                    <Text style={styles.structuredDataText}>
                      Security: {barcode.wifi.encryptionType}
                    </Text>
                  </View>
                )}

                {barcode.url && (
                  <View style={styles.structuredData}>
                    <Text style={styles.structuredDataTitle}>URL:</Text>
                    <Text style={styles.structuredDataText}>{barcode.url}</Text>
                  </View>
                )}

                {barcode.contact && (
                  <View style={styles.structuredData}>
                    <Text style={styles.structuredDataTitle}>Contact:</Text>
                    <Text style={styles.structuredDataText}>
                      Name: {barcode.contact.name}
                    </Text>
                    {barcode.contact.phones &&
                      barcode.contact.phones.length > 0 && (
                        <Text style={styles.structuredDataText}>
                          Phone: {barcode.contact.phones[0]}
                        </Text>
                      )}
                  </View>
                )}
              </View>
            ))
          ) : (
            <Text style={styles.noResults}>No barcodes detected</Text>
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
    flex: 2,
    backgroundColor: '#000',
  },
  overlay: {
    position: 'absolute',
    top: 20,
    left: 20,
    right: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    padding: 12,
    borderRadius: 8,
  },
  overlayText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 4,
  },
  overlayBarcode: {
    color: '#fff',
    fontSize: 12,
    marginTop: 2,
  },
  controls: {
    backgroundColor: '#fff',
    padding: 12,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    flexDirection: 'row',
    justifyContent: 'space-around',
    flexWrap: 'wrap',
    gap: 8,
  },
  filterButton: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: '#f0f0f0',
    marginHorizontal: 4,
  },
  filterButtonActive: {
    backgroundColor: '#007AFF',
  },
  filterButtonText: {
    fontSize: 14,
    color: '#333',
    fontWeight: '600',
  },
  filterButtonTextActive: {
    color: '#fff',
  },
  results: {
    flex: 1,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  resultsTitle: {
    fontSize: 16,
    fontWeight: '600',
    padding: 12,
    color: '#333',
  },
  resultsScroll: {
    flex: 1,
    paddingHorizontal: 12,
  },
  barcodeCard: {
    backgroundColor: '#f9f9f9',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
    borderLeftWidth: 3,
    borderLeftColor: '#007AFF',
  },
  barcodeFormat: {
    fontSize: 12,
    fontWeight: '600',
    color: '#007AFF',
    marginBottom: 4,
  },
  barcodeValue: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
    marginBottom: 4,
  },
  barcodeType: {
    fontSize: 12,
    color: '#666',
  },
  structuredData: {
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  structuredDataTitle: {
    fontSize: 12,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  structuredDataText: {
    fontSize: 12,
    color: '#666',
  },
  noResults: {
    fontSize: 14,
    color: '#999',
    fontStyle: 'italic',
  },
});
