# Windows Setup Guide

## Prerequisites

### Package Manager

Install one of these package managers (winget is recommended as it ships with Windows 11):

**winget (recommended):**
Already included in Windows 11. For Windows 10, install "App Installer" from the Microsoft Store.

**Chocolatey (alternative):**
Open PowerShell as Administrator:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### Git

```powershell
winget install Git.Git
```

Configure:
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@pandaworks.com"
```

### Node.js (LTS)

```powershell
winget install OpenJS.NodeJS.LTS
```

Or use fnm:
```powershell
winget install Schniz.fnm
fnm install --lts
fnm use lts-latest
```

### pnpm

```powershell
npm install -g pnpm
```

### .NET SDK

```powershell
winget install Microsoft.DotNet.SDK.9
```

Verify: `dotnet --version`

### IDE

**VS Code:**
```powershell
winget install Microsoft.VisualStudioCode
```

Recommended extensions:
- C# Dev Kit
- Biome
- Tailwind CSS IntelliSense
- ESLint (legacy projects)

**Rider (for .NET development):**
```powershell
winget install JetBrains.Rider
```

## Mobile Development (Optional)

### Yarn

```powershell
npm install -g yarn
```

### Expo CLI

```powershell
npm install -g expo-cli
```

### Android Studio

```powershell
winget install Google.AndroidStudio
```

After installation:
1. Open Android Studio
2. Install Android SDK via SDK Manager
3. Set environment variables:
   - `ANDROID_HOME` = `%LOCALAPPDATA%\Android\Sdk`
   - Add to PATH: `%ANDROID_HOME%\emulator` and `%ANDROID_HOME%\platform-tools`

Note: iOS development requires macOS. Windows developers working on mobile should focus on Android.

## Windows-Specific Notes

### Line Endings

Configure Git to handle line endings correctly:
```bash
git config --global core.autocrlf true
```

### Long Paths

Enable long path support (required for node_modules):
```powershell
# Run as Administrator
git config --global core.longpaths true
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

### Terminal

Use Windows Terminal with Git Bash or PowerShell for the best experience:
```powershell
winget install Microsoft.WindowsTerminal
```

## Verification

Run these commands to verify the setup:

```powershell
git --version
node --version
pnpm --version
dotnet --version
```

For mobile:
```powershell
yarn --version
```
