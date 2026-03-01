# macOS Setup Guide

## Prerequisites

### Xcode Command Line Tools

```bash
xcode-select --install
```

### Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Git

```bash
brew install git
git config --global user.name "Your Name"
git config --global user.email "your.email@pandaworks.com"
```

### Node.js (LTS)

```bash
brew install node@22
```

Or use a version manager:
```bash
brew install fnm
fnm install --lts
fnm use lts-latest
```

### pnpm

```bash
npm install -g pnpm
```

### .NET SDK

```bash
brew install dotnet-sdk
```

Verify: `dotnet --version`

### IDE

**VS Code:**
```bash
brew install --cask visual-studio-code
```

Recommended extensions:
- C# Dev Kit
- Biome
- Tailwind CSS IntelliSense
- ESLint (legacy projects)

**Rider (for .NET development):**
```bash
brew install --cask rider
```

## Mobile Development (Optional)

### Yarn

```bash
npm install -g yarn
```

### Expo CLI

```bash
npm install -g expo-cli
```

### CocoaPods

```bash
brew install cocoapods
```

### Xcode

Install Xcode from the Mac App Store. After installation:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Open Xcode and accept the license agreement. Install iOS simulator runtimes from Xcode > Settings > Platforms.

### Android Studio (Optional)

```bash
brew install --cask android-studio
```

After installation:
1. Open Android Studio
2. Install Android SDK via SDK Manager
3. Set ANDROID_HOME in your shell profile:

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

## Verification

Run these commands to verify the setup:

```bash
git --version
node --version
pnpm --version
dotnet --version
```

For mobile:
```bash
yarn --version
pod --version
```
