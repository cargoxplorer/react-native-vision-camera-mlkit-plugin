/**
 * Test setup file
 * Loaded before running tests
 */

// Mock react-native-vision-camera
jest.mock('react-native-vision-camera', () => {
  const { mockVisionCameraProxy } = require('./__mocks__/VisionCameraProxy');
  return {
    VisionCameraProxy: mockVisionCameraProxy,
    useCameraDevice: jest.fn(),
    Camera: 'Camera',
  };
});

// Mock react-native NativeModules
jest.mock('react-native', () => {
  const { NativeModules } = require('./__mocks__/NativeModules');
  return {
    NativeModules,
    Platform: {
      OS: 'android',
      select: jest.fn((obj) => obj.android || obj.default),
    },
  };
});

// Mock react-native-worklets-core
jest.mock('react-native-worklets-core', () => ({
  Worklets: {
    createRunOnJS: jest.fn((fn) => fn),
    createRunOnWorklet: jest.fn((fn) => fn),
  },
}));

// Suppress console output during tests (optional)
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
};
