/**
 * Mock for react-native-vision-camera VisionCameraProxy
 */

export const mockPlugin = {
  call: jest.fn(),
};

export const mockVisionCameraProxy = {
  initFrameProcessorPlugin: jest.fn(() => mockPlugin),
  removeFrameProcessor: jest.fn(),
  setFrameProcessor: jest.fn(),
};

export const VisionCameraProxy = mockVisionCameraProxy;
