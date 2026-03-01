# Windows Prerequisites Reference

Tool reference table for Phase 2. Each entry follows the interaction model: explain, check, install, verify.

## Platform Setup

### Package Manager (winget)

**What it is:** Windows package manager. Ships with Windows 11. For Windows 10, install "App Installer" from the Microsoft Store.

| | Command |
|---|---------|
| Check | `winget --version` |
| Install | Already included in Windows 11. Windows 10: install "App Installer" from Microsoft Store |
| Verify | `winget --version` |

### Windows-Specific Configuration

**Line endings** - configure Git to handle Windows/Unix line ending differences:
```bash
git config --global core.autocrlf true
```

**Long paths** - required for node_modules (run as Administrator):
```powershell
git config --global core.longpaths true
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

**Terminal** - Windows Terminal provides the best experience:
```powershell
winget install Microsoft.WindowsTerminal
```

---

## Common Prerequisites

### Git

**What it is:** Version control system. All Pandahrms repos are hosted on GitHub.

| | Command |
|---|---------|
| Check | `git --version` |
| Install | `winget install Git.Git` |
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
| Install | `winget install OpenJS.NodeJS.LTS` |
| Verify | `node --version` |

Alternative (version manager):
```powershell
winget install Schniz.fnm
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
| Install | `winget install Microsoft.DotNet.SDK.9` |
| Verify | `dotnet --version` |

### IDE

**VS Code (recommended):**

| | Command |
|---|---------|
| Check | `code --version` |
| Install | `winget install Microsoft.VisualStudioCode` |
| Verify | `code --version` |

Recommended extensions: C# Dev Kit, Biome, Tailwind CSS IntelliSense

**Rider (for .NET development):**

| | Command |
|---|---------|
| Install | `winget install JetBrains.Rider` |

---

## Docker (if Docker deployment chosen)

### Docker Desktop

**What it is:** Provides the Docker engine and Docker Compose for running the full Pandahrms stack in containers.

| | Command |
|---|---------|
| Check | `docker --version` and `docker compose version` |
| Install | `winget install Docker.DockerDesktop` (then launch Docker Desktop) |
| Verify | `docker info` |

---

## IIS Prerequisites (if IIS deployment chosen)

### .NET 8 ASP.NET Core Hosting Bundle

**What it is:** Required to host .NET applications inside IIS. The regular .NET SDK is not enough - the Hosting Bundle adds the ASP.NET Core Module that lets IIS forward requests to .NET apps.

| | Command |
|---|---------|
| Check | Open IIS Manager > server name > Modules > look for `AspNetCoreModuleV2` |
| Install | Download from https://dotnet.microsoft.com/en-us/download/dotnet/8.0 (Hosting Bundle under ASP.NET Core Runtime) |
| Verify | `iisreset` then check Modules again |

### IIS URL Rewrite Module

**What it is:** Enables URL rewriting rules in IIS. Required by the API Gateway's Ocelot routing.

| | Command |
|---|---------|
| Check | Open IIS Manager > server name > look for "URL Rewrite" icon |
| Install | Download from https://www.iis.net/downloads/microsoft/url-rewrite |
| Verify | "URL Rewrite" icon visible in IIS Manager |

### Application Request Routing (ARR)

**What it is:** Enables IIS to act as a reverse proxy. Required for the API Gateway and for proxying to Node.js services.

| | Command |
|---|---------|
| Check | Open IIS Manager > server name > look for "Application Request Routing Cache" icon |
| Install | Download from https://www.iis.net/downloads/microsoft/application-request-routing |
| Verify | "Application Request Routing Cache" icon visible in IIS Manager |

**After install - enable proxy:**
1. Open IIS Manager
2. Click on the server name (root node)
3. Double-click "Application Request Routing Cache"
4. Click "Server Proxy Settings" on the right
5. Check "Enable proxy"
6. Click "Apply"

### SQL Server

**What it is:** The database server. Use Express (free) or Developer edition for local development.

| | Command |
|---|---------|
| Check | `sqlcmd -S localhost -Q "SELECT @@VERSION"` |
| Install | `winget install Microsoft.SQLServer.2022.Express` |
| Verify | Connect via SSMS or Azure Data Studio |

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

### Android Studio

**What it is:** IDE for Android development. Provides the Android SDK and emulator.

| | Command |
|---|---------|
| Install | `winget install Google.AndroidStudio` |

After install:
1. Open Android Studio
2. Install Android SDK via SDK Manager
3. Set environment variables:
   - `ANDROID_HOME` = `%LOCALAPPDATA%\Android\Sdk`
   - Add to PATH: `%ANDROID_HOME%\emulator` and `%ANDROID_HOME%\platform-tools`

Note: iOS development requires macOS. Windows developers working on mobile should focus on Android.
