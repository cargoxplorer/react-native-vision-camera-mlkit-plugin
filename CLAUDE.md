# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a React Native Vision Camera frame processor plugin for Google ML Kit integration. It provides three core features:

1. **Text Recognition v2** - On-device OCR with multi-language support
2. **Barcode Scanning** - Fast barcode and QR code detection
3. **Document Scanner** - Document digitization (Android only)

**Key Architecture:**
- Frame processors for real-time camera processing
- Static image APIs for processing saved images
- Photo capture helpers for one-shot capture + process
- Custom logger with configurable log levels for performance
- Native implementations in Kotlin (Android) and Swift (iOS)
- Integration with react-native-vision-camera and react-native-worklets-core

## Development Commands

### Building and Testing
```bash
# Install dependencies (MUST use Yarn)
yarn

# Build the library
yarn prepare

# Type checking
yarn typecheck

# Linting
yarn lint
yarn lint --fix

# Run tests
yarn test
yarn test:coverage

# Clean build artifacts
yarn clean
```

### Example App
```bash
cd example

# Install dependencies
yarn

# Start Metro bundler
yarn start

# Run on platforms
yarn android
yarn ios
```

## Architecture

### TypeScript/JavaScript Layer (src/)
- **index.ts** - Main entry point exporting all features
- **types.ts** - Comprehensive TypeScript type definitions
- **utils/Logger.ts** - Custom logger with log levels
- **textRecognition.ts** - Text Recognition v2 plugin (TBD)
- **barcodeScanning.ts** - Barcode scanning plugin (TBD)
- **documentScanner.ts** - Document scanner plugin (TBD)
- **__tests__/** - Jest unit tests (TDD approach)

### Frame Processor Architecture
Uses Vision Camera's frame processor plugin system:
1. Plugins initialized via `VisionCameraProxy.initFrameProcessorPlugin()`
2. JavaScript creates plugin instances with options
3. Native plugins process camera frames in real-time
4. Results returned as worklet-compatible objects

### Native Layer

**Android (android/src/main/java/com/rnvisioncameramlkit/):**
- **RNVisionCameraMLKitPackage.kt** - Package registration
- **utils/Logger.kt** - Native logger
- Plugins (TBD):
  - TextRecognitionPlugin.kt
  - BarcodeScanningPlugin.kt
  - DocumentScannerPlugin.kt

**iOS (ios/):**
- To be implemented after Android is complete and tested

### Dependencies
- **react-native-vision-camera** ^4.7.3 - Core camera functionality
- **react-native-worklets-core** ^1.6.2 - Enables worklets
- **Google ML Kit** - On-device recognition models

## Code Conventions

### Commit Messages
Follow conventional commits:
- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code refactoring
- `docs:` - Documentation changes
- `test:` - Test additions/updates
- `chore:` - Tooling changes

### Linting
- ESLint with @react-native preset
- Prettier with single quotes, 2-space tabs, trailing commas (es5)

### Testing
- Jest with react-native preset
- **TDD approach**: Write tests BEFORE implementing features
- Coverage threshold: 80% for all metrics
- Tests in `src/__tests__/` directory

### TypeScript
- Strict mode enabled
- No unused locals or parameters
- No implicit returns
- Worklet functions must include `'worklet'` directive

## Development Process

### Test-Driven Development (TDD)
1. Write unit tests for the feature FIRST
2. Run tests (they should fail)
3. Implement the minimum code to pass tests
4. Refactor and optimize
5. Ensure all tests pass and coverage is >80%

### Phased Development
Development follows a phased approach tracked in **project-plan.md**:

**Phase 1:** ✅ Project Setup & Infrastructure (COMPLETE)
**Phase 2:** Text Recognition v2 (Android - TDD)
**Phase 3:** Barcode Scanning (Android - TDD)
**Phase 4:** Document Scanner (Android - TDD)
**Phase 5:** Integration & Polish (Android)
**Phase 6:** Example App (Android)
**Phase 7:** iOS Implementation
**Phase 8:** Documentation & Release

### Platform Priority
- **Android first** - Complete and test all features on Android
- **Then iOS** - Implement iOS after Android is validated
- **Exception**: Document Scanner is Android-only (Google limitation)

## Important Notes

- **Package manager:** This is a Yarn workspace monorepo. Do NOT use npm.
- **Frame processors:** Always include `'worklet'` directive in frame processor functions
- **Logging:** Use the custom Logger with appropriate log levels to minimize performance impact
- **Performance target:** <16ms frame processing time
- **Error handling:** Comprehensive error handling with informative messages
- **Native changes:** Require rebuild; JS changes hot reload
- **Builder Bob:** Outputs to lib/ directory in commonjs, module, and typescript formats
- **Main branch:** `main`

## ML Kit Integration

### Android Dependencies (build.gradle)
```gradle
// Text Recognition v2
implementation 'com.google.android.gms:play-services-mlkit-text-recognition:19.0.1'
implementation 'com.google.android.gms:play-services-mlkit-text-recognition-chinese:16.0.1'
implementation 'com.google.android.gms:play-services-mlkit-text-recognition-devanagari:16.0.1'
implementation 'com.google.android.gms:play-services-mlkit-text-recognition-japanese:16.0.1'
implementation 'com.google.android.gms:play-services-mlkit-text-recognition-korean:16.0.1'

// Document Scanner
implementation 'com.google.android.gms:play-services-mlkit-document-scanner:16.0.0-beta1'

// Barcode Scanning
implementation 'com.google.mlkit:barcode-scanning:17.3.0'
```

### iOS Dependencies (podspec)
```ruby
s.dependency "GoogleMLKit/TextRecognition", '>= 8.0.0'
s.dependency "GoogleMLKit/BarcodeScanning", '>= 7.0.0'
# Note: Document Scanner not available on iOS
```

## Project Tracking

**All progress is tracked in project-plan.md** including:
- Phase completion status
- Task checklists
- Testing results
- Known issues
- Performance benchmarks
- Decisions log

## Performance Considerations

- Use Logger.DEBUG level only during development
- Set Logger.WARN or Logger.ERROR in production
- Profile frame processing times regularly
- Target: <16ms per frame for 60fps
- Use `Logger.performance()` to track timing

## CI/CD

Will be set up in Phase 8:
- Linting & Tests run on all PRs
- PR titles must follow conventional commits
- Android/iOS builds tested in CI
- Coverage reports generated

## Reference Implementation

The codebase is based on patterns from:
- **react-native-vision-camera-ocr-plus** - Located at Q:\Dev\react-native-vision-camera-ocr-plus
- Study that implementation for frame processor patterns, native integration, and testing strategies
