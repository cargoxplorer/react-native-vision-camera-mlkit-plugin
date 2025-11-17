# Contributing to react-native-vision-camera-ml-kit

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/react-native-vision-camera-ml-kit.git
   cd react-native-vision-camera-ml-kit
   ```

2. **Install dependencies**
   ```bash
   yarn
   ```

3. **Run tests**
   ```bash
   yarn test
   ```

## Development Workflow

### Test-Driven Development (TDD)

This project follows TDD principles:

1. **Write tests first** - Before implementing a feature, write unit tests
2. **Run tests** - Verify they fail (red phase)
3. **Implement feature** - Write minimal code to pass tests (green phase)
4. **Refactor** - Improve code quality while keeping tests passing
5. **Verify coverage** - Ensure coverage remains >80%

Example:
```bash
# 1. Write test in src/__tests__/
# 2. Run tests (should fail)
yarn test

# 3. Implement feature
# 4. Run tests again (should pass)
yarn test

# 5. Check coverage
yarn test:coverage
```

### Code Quality

Before submitting a PR:

```bash
# Type check
yarn typecheck

# Lint
yarn lint

# Run tests with coverage
yarn test:coverage
```

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code refactoring
- `docs:` - Documentation changes
- `test:` - Test additions/updates
- `chore:` - Tooling/build changes
- `perf:` - Performance improvements

Examples:
```
feat: add barcode format filtering option
fix: handle null frame in text recognition
docs: update API documentation for document scanner
test: add unit tests for logger
```

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes following TDD**
   - Write tests first
   - Implement feature
   - Ensure tests pass
   - Verify coverage

3. **Update documentation**
   - Update README.md if adding new features
   - Add JSDoc comments to public APIs
   - Update CHANGELOG.md

4. **Commit your changes**
   ```bash
   git commit -m "feat: your feature description"
   ```

5. **Push to your fork**
   ```bash
   git push origin feat/your-feature-name
   ```

6. **Open a Pull Request**
   - Use a clear title following commit conventions
   - Describe what the PR does and why
   - Reference any related issues
   - Ensure CI passes

## Code Style

- **TypeScript**: Strict mode enabled
- **Formatting**: Prettier with 2-space indentation, single quotes
- **Linting**: ESLint with @react-native preset
- **Naming**:
  - Files: camelCase (e.g., `textRecognition.ts`)
  - Classes/Types: PascalCase (e.g., `TextRecognitionPlugin`)
  - Functions: camelCase (e.g., `createTextRecognitionPlugin`)
  - Constants: UPPER_SNAKE_CASE (e.g., `LOG_TAG`)

## Testing Guidelines

### Unit Tests
- Place in `src/__tests__/` mirroring source structure
- Mock external dependencies (VisionCameraProxy, NativeModules)
- Test error cases and edge cases
- Aim for >80% coverage

Example test structure:
```typescript
import { createTextRecognitionPlugin } from '../textRecognition';

describe('createTextRecognitionPlugin', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should create plugin with default options', () => {
    // Test implementation
  });

  it('should handle errors when plugin fails to load', () => {
    // Test implementation
  });
});
```

### Integration Tests
- Test TypeScript ↔ Native communication
- Verify data serialization/deserialization
- Test realistic usage scenarios

## Performance Considerations

- Keep frame processing under 16ms for 60fps
- Use Logger with appropriate log levels
- Profile critical paths
- Avoid unnecessary object allocations in hot paths
- Use `Logger.performance()` to track timing

## Platform-Specific Notes

### Android
- Kotlin code in `android/src/main/java/com/rnvisioncameramlkit/`
- Minimum SDK: 21
- Target SDK: 34
- Test on multiple Android versions

### iOS
- Swift code in `ios/`
- Minimum iOS version: 16.0
- Test on multiple iOS versions
- Document Scanner not supported on iOS

## Need Help?

- Check existing [Issues](https://github.com/yourusername/react-native-vision-camera-ml-kit/issues)
- Read the [Documentation](README.md)
- Ask questions in [Discussions](https://github.com/yourusername/react-native-vision-camera-ml-kit/discussions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
