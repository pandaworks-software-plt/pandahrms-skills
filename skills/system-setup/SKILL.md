---
name: system-setup
description: Use when setting up a new developer workstation for Pandahrms development, onboarding a new team member, or troubleshooting environment configuration issues across the monorepo workspace
---

# System Setup

## Overview

Guide new developers through setting up the complete Pandahrms development environment. Covers the full monorepo workspace across all projects with platform-specific instructions.

**Announce at start:** "I'm using the system-setup skill to configure the development environment."

## Platform Detection

Detect the platform automatically and load the appropriate guide:

- **macOS:** Read `mac-setup.md` in this skill directory
- **Windows:** Read `windows-setup.md` in this skill directory

## The Process

### Step 1: Prerequisites

Verify or install required tools. Ask the user which roles they will work on (frontend, backend, mobile, all) to skip irrelevant steps.

**All roles:**
- Git
- Node.js (LTS)
- pnpm (`npm install -g pnpm`)
- .NET SDK
- IDE (VS Code recommended, Rider for .NET)

**Mobile development (additional):**
- Yarn
- Expo CLI (`npm install -g expo-cli`)
- macOS: Xcode CLI tools + CocoaPods
- Android: Android Studio + SDK

### Step 2: Clone Repositories

Create the workspace directory and clone all required repos:

```bash
mkdir -p ~/Developer/pandaworks/_pandahrms-workspace
cd ~/Developer/pandaworks/_pandahrms-workspace
```

**Repositories to clone:**

| Project | Repo |
|---------|------|
| PandaHRMS_Api | Main backend API |
| Pandahrms_PerformanceApi | Performance backend |
| Pandahrms_RecruitmentApi | Recruitment backend |
| Pandahrms_ApiGateway | API Gateway |
| Pandahrms_Web | Web backend |
| pandahrms-shared | Shared .NET library |
| Pandahrms-Performance | Performance frontend |
| Pandahrms-Recruitment | Recruitment frontend |
| pandahrms-sso | SSO frontend |
| pandaworks-app | Mobile app |
| pandahrms-spec | Specifications |

Also create shared bridge directories:
```bash
mkdir -p performance-shared/bridge
mkdir -p pandahrms-app-shared/bridge
```

### Step 3: Install Dependencies

**Frontend projects (Next.js):**
```bash
cd Pandahrms-Performance && pnpm install && cd ..
cd Pandahrms-Recruitment && pnpm install && cd ..
cd pandahrms-sso && pnpm install && cd ..
```

**Mobile app:**
```bash
cd pandaworks-app && yarn install && cd ..
```

**Backend projects (.NET):**
```bash
cd PandaHRMS_Api && dotnet restore && cd ..
cd Pandahrms_PerformanceApi && dotnet restore && cd ..
cd Pandahrms_RecruitmentApi && dotnet restore && cd ..
```

### Step 4: Environment Configuration

Each project needs its own environment file. Walk through each one and prompt for required values (API URLs, database connections, secrets).

**Frontend projects:** `.env.local` files
**Backend projects:** `appsettings.Development.json` or user secrets
**Mobile app:** `.env` file

Never commit environment files. Add them to `.gitignore` if not already present.

### Step 5: Generate API Types

For frontend and mobile projects that consume APIs:

```bash
cd Pandahrms-Performance && pnpm generate-api && cd ..
cd Pandahrms-Recruitment && pnpm generate-api && cd ..
cd pandahrms-sso && pnpm generate-api && cd ..
cd pandaworks-app && yarn generate-api && cd ..
```

### Step 6: Verify Setup

Run each project to confirm it works:

**Frontend:** `pnpm dev` (should start on port 3000 or 8000)
**Backend:** `dotnet run --project <Project>/<Project>.csproj`
**Mobile:** `npx expo start`

### Step 7: Claude Code Setup

Install Claude Code plugins (run these inside Claude Code):

```
/plugins marketplace add obra/superpowers
/plugins marketplace add pandaworks-software-plt/pandahrms-skills
```

Point the developer to each project's `CLAUDE.md` for project-specific conventions.

## Checklist

- [ ] Platform detected (macOS or Windows)
- [ ] Developer role identified (frontend/backend/mobile/all)
- [ ] Prerequisites installed and verified
- [ ] Workspace directory created
- [ ] All required repositories cloned
- [ ] Bridge directories created
- [ ] Dependencies installed per project
- [ ] Environment files configured (no secrets committed)
- [ ] API types generated
- [ ] Each project runs successfully
- [ ] Claude Code plugins installed
