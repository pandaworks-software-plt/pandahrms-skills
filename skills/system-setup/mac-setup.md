# macOS Prerequisites Reference

Tool reference table for Phase 2. Each entry follows the interaction model: explain, check, install, verify.

## Platform Setup

### Xcode Command Line Tools

**What it is:** Provides compilers, Git, and other developer tools needed by Homebrew and native dependencies.

| | Command |
|---|---------|
| Check | `xcode-select -p` |
| Install | `xcode-select --install` |
| Verify | `xcode-select -p` (should show `/Library/Developer/CommandLineTools`) |

### Homebrew

**What it is:** macOS package manager. Used to install most development tools below.

| | Command |
|---|---------|
| Check | `brew --version` |
| Install | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| Verify | `brew --version` |

---

## Common Prerequisites

### Git

**What it is:** Version control system. All Pandahrms repos are hosted on GitHub.

| | Command |
|---|---------|
| Check | `git --version` |
| Install | `brew install git` |
| Verify | `git --version` |

After install, configure identity:
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@pandaworks.com"
```

### Node.js (LTS)

**What it is:** JavaScript runtime. Required for all Next.js frontend projects and the mobile app.

| | Command |
|---|---------|
| Check | `node --version` |
| Install | `brew install node@22` |
| Verify | `node --version` |

Alternative (version manager):
```bash
brew install fnm
fnm install --lts
fnm use lts-latest
```

### pnpm

**What it is:** Fast, disk-efficient package manager. Used by all Next.js frontend projects.

| | Command |
|---|---------|
| Check | `pnpm --version` |
| Install | `npm install -g pnpm` |
| Verify | `pnpm --version` |

### .NET SDK

**What it is:** Development kit for building and running .NET backend APIs.

| | Command |
|---|---------|
| Check | `dotnet --version` |
| Install | `brew install dotnet-sdk` |
| Verify | `dotnet --version` |

### IDE

**VS Code (recommended):**

| | Command |
|---|---------|
| Check | `code --version` |
| Install | `brew install --cask visual-studio-code` |
| Verify | `code --version` |

Recommended extensions: C# Dev Kit, Biome, Tailwind CSS IntelliSense

**Rider (for .NET development):**

| | Command |
|---|---------|
| Install | `brew install --cask rider` |

---

## Docker (if Docker deployment chosen)

### Docker Desktop

**What it is:** Provides the Docker engine and Docker Compose for running the full Pandahrms stack in containers.

| | Command |
|---|---------|
| Check | `docker --version && docker compose version` |
| Install | `brew install --cask docker` (then launch Docker Desktop from Applications) |
| Verify | `docker info` |

---

## Mobile Development (if mobile role)

### Yarn

**What it is:** Package manager used by the Expo mobile app project.

| | Command |
|---|---------|
| Check | `yarn --version` |
| Install | `npm install -g yarn` |
| Verify | `yarn --version` |

### Expo CLI

**What it is:** CLI for building and running the React Native mobile app.

| | Command |
|---|---------|
| Check | `expo --version` |
| Install | `npm install -g expo-cli` |
| Verify | `expo --version` |

### CocoaPods

**What it is:** iOS dependency manager. Required for building the iOS app.

| | Command |
|---|---------|
| Check | `pod --version` |
| Install | `brew install cocoapods` |
| Verify | `pod --version` |

### Xcode

**What it is:** Apple's IDE. Required for iOS simulator and native iOS builds.

| | Command |
|---|---------|
| Check | `xcodebuild -version` |
| Install | Install from the Mac App Store |

After install:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Open Xcode, accept the license, and install iOS simulator runtimes from Xcode > Settings > Platforms.

### Android Studio (optional)

**What it is:** IDE for Android development. Provides the Android SDK and emulator.

| | Command |
|---|---------|
| Install | `brew install --cask android-studio` |

After install:
1. Open Android Studio
2. Install Android SDK via SDK Manager
3. Add to shell profile:
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
```
