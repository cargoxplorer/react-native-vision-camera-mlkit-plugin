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
  useTextRecognition,
  TextRecognitionScript,
  type TextRecognitionResult,
} from 'react-native-vision-camera-ml-kit';
import { useAppLifecycle } from './utils/useAppLifecycle';

export default function TextRecognitionScreen() {
  const [hasPermission, setHasPermission] = useState(false);
  const [result, setResult] = useState<TextRecognitionResult | null>(null);
  const [language, setLanguage] = useState<TextRecognitionScript>(
    TextRecognitionScript.LATIN
  );
  const [isActive, setIsActive] = useState(true);

  const device = useCameraDevice('back');
  const format = useCameraFormat(device, [
    { videoResolution: { width: 1280, height: 720 } },
    { fps: 60 },
  ]);
  // Memoize options so the plugin isn't recreated on every render
  const textOptions = React.useMemo(() => ({ language }), [language]);
  const { scanText } = useTextRecognition(textOptions);

  React.useEffect(() => {
    (async () => {
      const status = await Camera.requestCameraPermission();
      setHasPermission(status === 'granted');
    })();
  }, []);

  // Handle app lifecycle - pause camera when app goes to background
  useAppLifecycle(setIsActive);

  const onTextDetected = Worklets.createRunOnJS(
    (textResult: TextRecognitionResult | null) => {
      // Avoid unnecessary React re-renders when text hasn't changed
      setResult((prev) => {
        if (!prev && !textResult) return prev;
        if (prev?.text === textResult?.text) return prev;
        return textResult;
      });
    }
  );

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      // Throttle OCR to avoid running on every single frame
      runAtTargetFps(1, () => {
        'worklet';
        // Run async to prevent blocking the camera thread (OCR is expensive ~50-150ms)
        runAsync(frame, () => {
          'worklet';
          try {
            const textResult = scanText(frame);
            onTextDetected(textResult);
          } catch (error) {
            console.error('Frame processing error:', error);
          }
        });
      });
    },
    [scanText]
  );

  const languages = [
    { label: 'Latin', value: TextRecognitionScript.LATIN },
    { label: 'Chinese', value: TextRecognitionScript.CHINESE },
    { label: 'Devanagari', value: TextRecognitionScript.DEVANAGARI },
    { label: 'Japanese', value: TextRecognitionScript.JAPANESE },
    { label: 'Korean', value: TextRecognitionScript.KOREAN },
  ];

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

        {result && (
          <View style={styles.overlay}>
            <Text style={styles.overlayText}>
              {result.blocks.length} block(s) detected
            </Text>
          </View>
        )}
      </View>

      <View style={styles.controls}>
        <Text style={styles.controlsTitle}>Language:</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          {languages.map((lang) => (
            <TouchableOpacity
              key={lang.value}
              style={[
                styles.languageButton,
                language === lang.value && styles.languageButtonActive,
              ]}
              onPress={() => setLanguage(lang.value)}
            >
              <Text
                style={[
                  styles.languageButtonText,
                  language === lang.value && styles.languageButtonTextActive,
                ]}
              >
                {lang.label}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      <View style={styles.results}>
        <Text style={styles.resultsTitle}>Detected Text:</Text>
        <ScrollView style={styles.resultsScroll}>
          {result?.text ? (
            <>
              <Text style={styles.resultText}>{result.text}</Text>
              <Text style={styles.resultsMeta}>
                {result.blocks.length} blocks,{' '}
                {result.blocks.reduce((sum, b) => sum + b.lines.length, 0)}{' '}
                lines
              </Text>
            </>
          ) : (
            <Text style={styles.noResults}>No text detected</Text>
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
  },
  controls: {
    backgroundColor: '#fff',
    padding: 12,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  controlsTitle: {
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 8,
    color: '#333',
  },
  languageButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#f0f0f0',
    marginRight: 8,
  },
  languageButtonActive: {
    backgroundColor: '#007AFF',
  },
  languageButtonText: {
    fontSize: 14,
    color: '#333',
  },
  languageButtonTextActive: {
    color: '#fff',
    fontWeight: '600',
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
  resultText: {
    fontSize: 14,
    color: '#333',
    lineHeight: 20,
  },
  resultsMeta: {
    fontSize: 12,
    color: '#999',
    marginTop: 8,
    paddingBottom: 12,
  },
  noResults: {
    fontSize: 14,
    color: '#999',
    fontStyle: 'italic',
  },
});
