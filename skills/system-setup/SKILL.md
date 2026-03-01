---
name: system-setup
description: Use when setting up a new developer workstation for Pandahrms development, onboarding a new team member, or troubleshooting environment configuration issues across the monorepo workspace
---

# System Setup

## Overview

Guide new developers through setting up the complete Pandahrms development environment. This skill operates as a phased pipeline - shared prerequisites first, then deployment based on the developer's chosen method (Docker or IIS).

**Announce at start:** "I'm using the system-setup skill to configure the development environment."

## Interaction Model

For EVERY step in this skill:

1. **Explain** what the tool/component is and why it's needed (1-2 sentences)
2. **Check** if it's already installed or done (run a check command)
3. **Show** the exact command that will be run
4. **Ask permission** before executing

Never run installation commands without the developer's explicit approval.

## The Pipeline

```
Phase 1: Gather Info
    |
Phase 2: Prerequisites (shared - platform-specific)
    |
Phase 3: Clone & Configure (shared)
    |
Phase 4: Deployment (Docker OR IIS)
    |
Phase 5: Verification & Tooling
```

---

## Phase 1: Gather Info

Collect three pieces of information before starting:

### 1. Platform Detection

Detect automatically via the OS. Confirm with the developer.

- **macOS** - will use `mac-setup.md` for prerequisites
- **Windows** - will use `windows-setup.md` for prerequisites

### 2. Developer Role

Ask which areas they will work on. This determines which repos to clone and which dependencies to install.

| Role | Repos | Dependencies |
|------|-------|--------------|
| **Frontend** | FE projects + specs | Node.js, pnpm |
| **Backend** | BE projects + shared lib | .NET SDK |
| **Mobile** | Mobile app + specs | Node.js, Yarn, Expo, Xcode/Android Studio |
| **All** | Everything | All of the above |

### 3. Deployment Method

Ask how they want to run the stack locally:

| Method | Best for | Platform |
|--------|----------|----------|
| **Docker** | Full stack with one command, containers handle everything | macOS or Windows |
| **IIS (non-Docker)** | Running .NET in IIS, Next.js as Windows services | Windows only |

If they choose IIS on macOS, inform them IIS is Windows-only and suggest Docker.

---

## Phase 2: Prerequisites

Load the platform-specific reference file:

- **macOS:** Read `mac-setup.md` in this skill directory
- **Windows:** Read `windows-setup.md` in this skill directory

Walk through each prerequisite from the reference file using the interaction model (explain, check, show, ask).

**Common prerequisites (all platforms):**
- Git
- Node.js (LTS)
- pnpm
- .NET SDK (if backend or all role)
- IDE (VS Code recommended)

**If Docker deployment chosen:**
- Docker Desktop

**If IIS deployment chosen (Windows only):**
- .NET 8 ASP.NET Core Hosting Bundle
- IIS URL Rewrite Module
- Application Request Routing (ARR)
- SQL Server (Express or Developer edition)

**If mobile role:**
- Yarn
- Expo CLI
- macOS: Xcode CLI tools + CocoaPods
- Android: Android Studio + SDK

---

## Phase 3: Clone & Configure

### 3.1 Create Workspace

```bash
mkdir -p ~/Developer/pandaworks/_pandahrms-workspace
cd ~/Developer/pandaworks/_pandahrms-workspace
```

### 3.2 Clone Repositories

Clone only the repos relevant to the developer's role. All repos are under the `pandaworks-software-plt` GitHub organization.

| Project | Type | Roles |
|---------|------|-------|
| PandaHRMS_Api | Backend | backend, all |
| Pandahrms_PerformanceApi | Backend | backend, all |
| Pandahrms_RecruitmentApi | Backend | backend, all |
| Pandahrms_ApiGateway | Backend | backend, all |
| Pandahrms_Web | Backend | backend, all |
| pandahrms-shared | Shared lib | backend, all |
| Pandahrms-Performance | Frontend | frontend, all |
| Pandahrms-Recruitment | Frontend | frontend, all |
| pandahrms-sso | Frontend | frontend, all |
| pandaworks-app | Mobile | mobile, all |
| pandahrms-spec | Specs | all roles |

### 3.3 Create Bridge Directories

```bash
mkdir -p performance-shared/bridge
mkdir -p pandahrms-app-shared/bridge
```

### 3.4 Install Dependencies

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

Only run the commands relevant to the developer's role.

---

## Phase 4: Deployment

Load the deployment-specific guide:

- **Docker:** Read `docker-deployment.md` in this skill directory
- **IIS:** Read `iis-deployment.md` in this skill directory

Follow the loaded guide step by step using the interaction model.

---

## Phase 5: Verification & Tooling

### 5.1 Verify Services

After deployment, verify that all services are running and accessible:

| Service | Docker URL | IIS URL |
|---------|-----------|---------|
| API Gateway | http://localhost:8080 | Configured in IIS |
| Main API | http://localhost:8010 | IIS web app `/apps` |
| Performance API | http://localhost:8011 | IIS web app |
| SSO | http://localhost:8000 | IIS web app `/sso` |
| Performance FE | http://localhost:8001 | IIS web app |

### 5.2 Generate API Types

For frontend and mobile projects that consume APIs (only after backends are running):

```bash
cd Pandahrms-Performance && pnpm generate-api && cd ..
cd Pandahrms-Recruitment && pnpm generate-api && cd ..
cd pandahrms-sso && pnpm generate-api && cd ..
cd pandaworks-app && yarn generate-api && cd ..
```

### 5.3 Claude Code Setup

Install Claude Code plugins (run these inside Claude Code):

```
/plugins marketplace add obra/superpowers
/plugins marketplace add pandaworks-software-plt/pandahrms-skills
```

Point the developer to each project's `CLAUDE.md` for project-specific conventions.

---

## Checklist

### Phase 1
- [ ] Platform detected and confirmed
- [ ] Developer role identified
- [ ] Deployment method chosen

### Phase 2
- [ ] All prerequisites installed and verified

### Phase 3
- [ ] Workspace directory created
- [ ] Required repositories cloned
- [ ] Bridge directories created
- [ ] Dependencies installed per project

### Phase 4
- [ ] Deployment completed (Docker or IIS)
- [ ] All services running

### Phase 5
- [ ] All services accessible and responding
- [ ] API types generated (if frontend/mobile role)
- [ ] Claude Code plugins installed
