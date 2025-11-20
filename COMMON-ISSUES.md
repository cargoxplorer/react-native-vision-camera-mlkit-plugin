# Common Issues and Solutions

Quick reference for common issues encountered during development and CI.

---

## Pod Dependency Names vs npm Package Names

### Issue
```
[!] Unable to find a specification for `react-native-vision-camera`
```

### Cause
CocoaPods pod names are often different from npm package names.

### Solution
Use the correct pod name in your `.podspec` file:

| npm Package | Pod Name (for podspec) |
|-------------|------------------------|
| `react-native-vision-camera` | `VisionCamera` |
| `react-native-worklets-core` | `react-native-worklets-core` |
| `react-native-screens` | `RNScreens` |
| `react-native-safe-area-context` | `react-native-safe-area-context` |
| `@react-native-community/slider` | `RNCSlider` |

**How to find the correct pod name:**
1. Look in the package's `.podspec` file
2. Check `Pod::Spec.new do |s|` → `s.name = "ActualPodName"`

---

## Workspaces Error When Publishing

### Issue
```
error Workspaces can only be enabled in private projects.
```

### Cause
Yarn workspaces require `"private": true"`, but npm packages must be public.

### Solution
Remove the `workspaces` field from `package.json`:

```json
{
  // Remove these:
  // "private": true,
  // "workspaces": ["example"]
}
```

Use `"link:.."` in example app instead:
```json
{
  "dependencies": {
    "your-library": "link:.."
  }
}
```

---

## gradlew Permission Denied in CI

### Issue
```
./gradlew: Permission denied
Error: Process completed with exit code 126
```

### Cause
gradlew file doesn't have execute permissions in the repository.

### Solution

**Option 1: Fix locally and commit**
```bash
chmod +x android/gradlew
git add android/gradlew
git commit -m "fix: add execute permission to gradlew"
```

**Option 2: Add step in CI**
```yaml
- name: Make gradlew executable
  run: chmod +x android/gradlew
```

---

## React Native Requires Xcode >= 16.1

### Issue
```
React Native requires XCode >= 16.1. Found 15.4.
```

### Cause
Using wrong macOS runner version in GitHub Actions.

### Solution
Use `macos-15` runner which has Xcode 16.2:

```yaml
jobs:
  ios-build:
    runs-on: macos-15  # Has Xcode 16.2
```

**Runner versions:**
- `macos-13` → Xcode 14.x (too old)
- `macos-14` → Xcode 15.4 (too old for RN 0.81+)
- `macos-15` → Xcode 16.2 ✅

---

## Higher Minimum Deployment Target

### Issue
```
CocoaPods could not find compatible versions...
they required a higher minimum deployment target.
```

### Cause
GoogleMLKit/TextRecognition version 8.0.0+ requires iOS 15.5 as minimum deployment target.

### Solution
Set the iOS deployment target to 15.5 to match GoogleMLKit requirements:

```ruby
# In your .podspec
s.platforms = { :ios => "15.5" }  # Required for GoogleMLKit 8.0.0+
```

**Important:** GoogleMLKit/TextRecognition 8.0.0+ requires iOS 15.5, which is higher than React Native's default of 13.4.

**Deployment targets:**
- GoogleMLKit/TextRecognition 8.0.0+: iOS 15.5 (required)
- React Native 0.70+: iOS 13.4 (default)
- React Native 0.68-0.69: iOS 12.4
- Expo default: iOS 13.4

---

## Expo Prebuild Required

### Issue
```
Could not find project.android.packageName in react-native config output!
```

### Cause
Expo apps don't have native directories committed to git. They must be generated.

### Solution
Add prebuild step before building:

```yaml
# Android
- name: Generate Android project
  run: |
    cd example
    npx expo prebuild --platform android --clean

# iOS
- name: Generate iOS project
  run: |
    cd example
    npx expo prebuild --platform ios --clean
```

---

## Module Not Found in CI

### Issue
```
Cannot find module 'react-native-your-library'
```

### Cause
Using `yarn install --frozen-lockfile` with non-workspace setup.

### Solution
Use regular `yarn install` without `--frozen-lockfile`:

```yaml
- name: Install dependencies
  run: yarn install  # Not --frozen-lockfile
```

---

## CocoaPods Cache Issues

### Issue
```
[!] CocoaPods could not find compatible versions...
```

### Cause
Outdated CocoaPods cache or repo.

### Solution

**Local:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
```

**CI:**
```yaml
- name: Install CocoaPods dependencies
  run: |
    cd ios
    pod install --repo-update
```

---

## Xcode Build Scheme Not Found

### Issue
```
xcodebuild: error: Scheme "YourApp" does not exist.
```

### Cause
Scheme name mismatch or workspace not found.

### Solution
Use wildcard for workspace name:

```bash
xcodebuild \
  -workspace *.xcworkspace \
  -scheme YourActualSchemeName \
  -configuration Debug
```

Find scheme name:
```bash
cd ios
xcodebuild -list -workspace *.xcworkspace
```

---

## Build Artifacts Not Found

### Issue
```
Error: No files were found with the provided path
```

### Cause
Build output path is incorrect or build failed.

### Solution
Verify the build output path:

**Android:**
```yaml
path: example/android/app/build/outputs/apk/debug/*.apk
```

**iOS:**
```yaml
path: example/ios/build/Build/Products/Debug-iphonesimulator/*.app
```

---

## npm Publish Permission Denied

### Issue
```
npm ERR! code E403
npm ERR! 403 Forbidden - PUT https://registry.npmjs.org/your-package
```
OR
```
ERROR Not authenticated with npm. Please `npm login` and try again.
```

### Cause
Missing or invalid NPM_TOKEN, or token not properly exposed to npm.

### Solution

1. Generate npm token: https://www.npmjs.com/settings/YOUR_USERNAME/tokens
2. Add to GitHub Secrets as `NPM_TOKEN`
3. Ensure token has "Automation" permissions
4. **Important**: When using `setup-node` with `registry-url`, the token must be exposed as `NODE_AUTH_TOKEN`:

```yaml
- name: Release
  run: npm run release
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}  # Required for setup-node
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}         # May be needed by release-it
```

---

## Git Working Directory Not Clean

### Issue
```
Error: Working directory is not clean
```

### Cause
release-it requires clean working directory.

### Solution
Commit all changes before releasing:

```bash
git status
git add .
git commit -m "chore: prepare for release"
```

---

## Package Name Already Taken

### Issue
```
npm ERR! 403 Forbidden - You do not have permission to publish "package-name"
```

### Cause
Package name is already taken on npm.

### Solution
1. Check: `npm search your-package-name`
2. Choose a different name in `package.json`
3. Update README and docs

---

## Type Errors in Build

### Issue
```
error TS2307: Cannot find module 'react-native-your-lib'
```

### Cause
Types not properly exported or built.

### Solution
Ensure build includes type definitions:

```json
{
  "main": "lib/commonjs/index",
  "types": "lib/typescript/index.d.ts",
  "react-native-builder-bob": {
    "targets": [
      "commonjs",
      "module",
      ["typescript", { "project": "tsconfig.build.json" }]
    ]
  }
}
```

---

## Summary Checklist

Before pushing to CI, verify:

- [ ] gradlew has execute permissions
- [ ] Pod dependency names are correct
- [ ] iOS deployment target matches React Native version
- [ ] Workspaces removed for npm publishing
- [ ] Expo prebuild steps included in CI
- [ ] Correct Xcode runner version (macos-15)
- [ ] NPM_TOKEN configured for releases

---

**Need more help?** Check the other docs:
- `BUILD-AND-PUBLISH.md` - Publishing guide
- `CI-CD-SETUP.md` - CI/CD details
- `IOS-TESTING-GUIDE.md` - iOS testing
- `WORKSPACE-FIX.md` - Workspace issues
