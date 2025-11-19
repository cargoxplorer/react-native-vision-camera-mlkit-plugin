import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Platform,
  Image,
  Alert,
} from 'react-native';
import {
  launchDocumentScanner,
  DocumentScannerMode,
  isCancellationError,
  type DocumentScanningResult,
} from 'react-native-vision-camera-ml-kit';
import { useAppLifecycle } from './utils/useAppLifecycle';

export default function DocumentScannerScreen() {
  const [result, setResult] = useState<DocumentScanningResult | null>(null);
  const [mode, setMode] = useState<DocumentScannerMode>(DocumentScannerMode.FULL);
  const [isScanning, setIsScanning] = useState(false);
  const [isAppActive, setIsAppActive] = useState(true);

  // Handle app lifecycle - prevent scanning when app is backgrounded
  useAppLifecycle(setIsAppActive);

  const handleScan = async () => {
    if (Platform.OS !== 'android') {
      Alert.alert(
        'Not Supported',
        'Document Scanner is only available on Android.'
      );
      return;
    }

    setIsScanning(true);

    try {
      const scanResult = await launchDocumentScanner({
        mode,
        pageLimit: 10,
        galleryImportEnabled: true,
      });

      setResult(scanResult);

      if (scanResult && scanResult.pages.length > 0) {
        Alert.alert(
          'Scan Complete',
          `Successfully scanned ${scanResult.pageCount} page(s)`
        );
      }
    } catch (error) {
      if (isCancellationError(error)) {
        console.log('User cancelled the scan');
      } else {
        Alert.alert('Error', `Scan failed: ${error}`);
        console.error('Document scan error:', error);
      }
    } finally {
      setIsScanning(false);
    }
  };

  const modes = [
    { label: 'BASE', value: DocumentScannerMode.BASE },
    { label: 'BASE + Filter', value: DocumentScannerMode.BASE_WITH_FILTER },
    { label: 'FULL (ML)', value: DocumentScannerMode.FULL },
  ];

  return (
    <View style={styles.container}>
      <ScrollView style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.title}>Document Scanner</Text>
          <Text style={styles.subtitle}>
            {Platform.OS === 'android'
              ? 'Tap "Scan Document" to launch ML Kit scanner'
              : 'Android Only - Not available on iOS'}
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Scanner Mode:</Text>
          <View style={styles.modeButtons}>
            {modes.map((m) => (
              <TouchableOpacity
                key={m.value}
                style={[
                  styles.modeButton,
                  mode === m.value && styles.modeButtonActive,
                ]}
                onPress={() => setMode(m.value)}
              >
                <Text
                  style={[
                    styles.modeButtonText,
                    mode === m.value && styles.modeButtonTextActive,
                  ]}
                >
                  {m.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <View style={styles.modeInfo}>
            <Text style={styles.modeInfoText}>
              {mode === DocumentScannerMode.BASE &&
                '• Crop, rotate, reorder pages'}
              {mode === DocumentScannerMode.BASE_WITH_FILTER &&
                '• Crop, rotate, reorder + image filters'}
              {mode === DocumentScannerMode.FULL &&
                '• All features + ML-powered cleaning'}
            </Text>
          </View>
        </View>

        <TouchableOpacity
          style={[
            styles.scanButton,
            (isScanning || Platform.OS !== 'android' || !isAppActive) && styles.scanButtonDisabled,
          ]}
          onPress={handleScan}
          disabled={isScanning || Platform.OS !== 'android' || !isAppActive}
        >
          <Text style={styles.scanButtonText}>
            {!isAppActive ? 'App in Background' : isScanning ? 'Scanning...' : 'Scan Document'}
          </Text>
        </TouchableOpacity>

        {result && result.pages.length > 0 && (
          <View style={styles.results}>
            <Text style={styles.resultsTitle}>
              Scanned {result.pageCount} Page(s)
            </Text>

            {result.pdfUri && (
              <View style={styles.pdfInfo}>
                <Text style={styles.pdfLabel}>PDF Generated:</Text>
                <Text style={styles.pdfUri} numberOfLines={2}>
                  {result.pdfUri}
                </Text>
              </View>
            )}

            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
              {result.pages.map((page) => (
                <View key={page.pageNumber} style={styles.pageCard}>
                  <Image
                    source={{ uri: page.uri }}
                    style={styles.pageImage}
                    resizeMode="cover"
                  />
                  <Text style={styles.pageNumber}>Page {page.pageNumber}</Text>
                  {page.processedSize && (
                    <Text style={styles.pageSize}>
                      {page.processedSize.width}x{page.processedSize.height}
                    </Text>
                  )}
                </View>
              ))}
            </ScrollView>
          </View>
        )}

        {!result && (
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateText}>
              No documents scanned yet
            </Text>
            <Text style={styles.emptyStateSubtext}>
              Use the "Scan Document" button above
            </Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    flex: 1,
  },
  header: {
    padding: 20,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  section: {
    padding: 16,
    backgroundColor: '#fff',
    marginTop: 8,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  modeButtons: {
    flexDirection: 'row',
    gap: 8,
  },
  modeButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#f0f0f0',
    alignItems: 'center',
  },
  modeButtonActive: {
    backgroundColor: '#007AFF',
  },
  modeButtonText: {
    fontSize: 12,
    color: '#333',
    fontWeight: '600',
  },
  modeButtonTextActive: {
    color: '#fff',
  },
  modeInfo: {
    marginTop: 8,
    padding: 12,
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
  },
  modeInfoText: {
    fontSize: 12,
    color: '#666',
  },
  scanButton: {
    backgroundColor: '#007AFF',
    padding: 16,
    margin: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  scanButtonDisabled: {
    backgroundColor: '#ccc',
  },
  scanButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  results: {
    padding: 16,
    backgroundColor: '#fff',
    marginTop: 8,
  },
  resultsTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  pdfInfo: {
    backgroundColor: '#f0f8ff',
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
  },
  pdfLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#007AFF',
    marginBottom: 4,
  },
  pdfUri: {
    fontSize: 11,
    color: '#666',
  },
  pageCard: {
    width: 120,
    marginRight: 12,
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
    overflow: 'hidden',
  },
  pageImage: {
    width: '100%',
    height: 160,
    backgroundColor: '#e0e0e0',
  },
  pageNumber: {
    fontSize: 12,
    fontWeight: '600',
    color: '#333',
    padding: 8,
    textAlign: 'center',
  },
  pageSize: {
    fontSize: 10,
    color: '#999',
    paddingHorizontal: 8,
    paddingBottom: 8,
    textAlign: 'center',
  },
  emptyState: {
    padding: 40,
    alignItems: 'center',
  },
  emptyStateText: {
    fontSize: 16,
    color: '#999',
  },
  emptyStateSubtext: {
    fontSize: 12,
    color: '#ccc',
    marginTop: 4,
  },
});
