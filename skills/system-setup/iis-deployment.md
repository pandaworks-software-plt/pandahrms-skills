# IIS Deployment

Local development setup using IIS for .NET backends and node-windows for Next.js frontends. Windows only.

## What This Sets Up

| Component | Hosting | Description |
|-----------|---------|-------------|
| Main API | IIS web application | Core Pandahrms .NET API |
| API Gateway | IIS web application | Ocelot reverse proxy |
| Performance API | IIS web application | Performance module .NET API |
| Recruitment API | IIS web application | Recruitment module .NET API |
| SSO | Windows service (node-windows) | Identity/SSO frontend (Next.js standalone) |
| Performance FE | Windows service (node-windows) | Performance frontend (Next.js standalone) |
| SQL Server | Local instance | SQL Server (Express or Developer edition) |

## Prerequisites

These are in addition to the common prerequisites from Phase 2.

### .NET 8 ASP.NET Core Hosting Bundle

**What it is:** Required to host .NET applications inside IIS. The regular .NET SDK alone is not enough - the Hosting Bundle adds the ASP.NET Core Module that lets IIS forward requests to .NET apps.

**Check:** Open IIS Manager > click server name > Modules > look for `AspNetCoreModuleV2`

**Install:** Download from https://dotnet.microsoft.com/en-us/download/dotnet/8.0 (look for "Hosting Bundle" under ASP.NET Core Runtime). Run the installer.

**Important:** Restart IIS after installation: `iisreset` in an admin command prompt.

### IIS URL Rewrite Module

**What it is:** Enables URL rewriting rules in IIS. Required by the API Gateway's Ocelot routing configuration.

**Check:** Open IIS Manager > click server name > look for "URL Rewrite" icon

**Install:** Download from https://www.iis.net/downloads/microsoft/url-rewrite and run the installer.

### Application Request Routing (ARR)

**What it is:** Enables IIS to act as a reverse proxy, forwarding requests to backend services. Required for the API Gateway to route requests to the correct API.

**Check:** Open IIS Manager > click server name > look for "Application Request Routing Cache" icon

**Install:** Download from https://www.iis.net/downloads/microsoft/application-request-routing and run the installer.

**After install - enable proxy:**
1. Open IIS Manager
2. Click on the server name (root node)
3. Double-click "Application Request Routing Cache"
4. Click "Server Proxy Settings" on the right
5. Check "Enable proxy"
6. Click "Apply"

### SQL Server

**What it is:** The database server. Use SQL Server Express (free) or Developer edition for local development.

**Check:** `sqlcmd -S localhost -Q "SELECT @@VERSION"` or connect via SSMS/Azure Data Studio

**Install:** `winget install Microsoft.SQLServer.2022.Express` or download from https://www.microsoft.com/en-us/sql-server/sql-server-downloads

---

## Step 1: Create Application Pool

Before deploying any application, create a shared Application Pool in IIS.

1. Open IIS Manager
2. Right-click "Application Pools" > "Add Application Pool..."
3. Configure:
   - **Name:** `pandahrms-unmanaged-app-pool`
   - **.NET CLR Version:** No Managed Code
   - **Managed Pipeline Mode:** Integrated
4. Click OK

**Why "No Managed Code":** ASP.NET Core apps run in their own process (Kestrel). IIS just forwards requests via the ASP.NET Core Module - it doesn't need the .NET CLR loaded in the app pool.

---

## Step 2: Deploy .NET Backend APIs

Repeat this for each .NET backend: Main API, API Gateway, Performance API, Recruitment API.

### 2.1 Publish the Project

From the workspace root, publish each project:

```powershell
# Main API
dotnet publish PandaHRMS_Api/PandaHRMS_Api/PandaHRMS_Api.csproj -c Release -o C:\inetpub\pandahrms\apps

# API Gateway
dotnet publish Pandahrms_ApiGateway/Pandahrms_ApiGateway/Pandahrms_ApiGateway.csproj -c Release -o C:\inetpub\pandahrms\api

# Performance API
dotnet publish Pandahrms_PerformanceApi/Pandahrms.Performance.Api/Pandahrms.Performance.Api.csproj -c Release -o C:\inetpub\pandahrms\performance-api

# Recruitment API
dotnet publish Pandahrms_RecruitmentApi/Pandahrms_RecruitmentApi/Pandahrms_RecruitmentApi.csproj -c Release -o C:\inetpub\pandahrms\recruitment-api
```

### 2.2 Create IIS Web Applications

1. Open IIS Manager
2. Under the Pandahrms website, right-click > "Add Application..."
3. Create these web applications:

| Alias | Physical Path | App Pool |
|-------|--------------|----------|
| `apps` | `C:\inetpub\pandahrms\apps` | `pandahrms-unmanaged-app-pool` |
| `api` | `C:\inetpub\pandahrms\api` | `pandahrms-unmanaged-app-pool` |
| `performance-api` | `C:\inetpub\pandahrms\performance-api` | `pandahrms-unmanaged-app-pool` |
| `recruitment-api` | `C:\inetpub\pandahrms\recruitment-api` | `pandahrms-unmanaged-app-pool` |

### 2.3 Configure appsettings.json

For the **Main API** (`C:\inetpub\pandahrms\apps\appsettings.json`):

Update these values:
- `ConnectionStrings.Default` - Set Server, Database, User Id, Password for your SQL Server
- `AppSettings.PandaHRMSBaseUrl` - The Pandahrms base URL

For the **Performance API** and **Recruitment API**:
- `ConnectionStrings.PerformanceConnectionString` / `RecruitmentConnectionString` - Same database connection
- `JwtTokenKey` - Must match the Main API's JWT key
- `Services.CustomApiBaseUrl` - URL of the Main API (e.g., `http://localhost/apps/api`)

### 2.4 Configure API Gateway ocelot.json

In `C:\inetpub\pandahrms\api\ocelot.json`:

1. Set each `Routes.DownstreamScheme` to `http` or `https`
2. In each `Routes.DownstreamHostAndPorts`, set `Host` and `Port` to your domain/port
   - Example: Host: `localhost`, Port: `80`

---

## Step 3: Deploy Next.js Frontends

Repeat this for each Next.js frontend: SSO, Performance.

### 3.1 Build Standalone Output

```powershell
# SSO
cd pandahrms-sso
pnpm install
pnpm build
cd ..

# Performance
cd Pandahrms-Performance
pnpm install
pnpm build
cd ..
```

The build output is in `.next/standalone/` - this is a self-contained Node.js application.

### 3.2 Deploy Files

Copy the standalone output to the deployment location:

```powershell
# SSO
xcopy /E /I pandahrms-sso\.next\standalone C:\inetpub\pandahrms\sso
xcopy /E /I pandahrms-sso\.next\static C:\inetpub\pandahrms\sso\.next\static
xcopy /E /I pandahrms-sso\public C:\inetpub\pandahrms\sso\public

# Performance
xcopy /E /I Pandahrms-Performance\.next\standalone C:\inetpub\pandahrms\performance
xcopy /E /I Pandahrms-Performance\.next\static C:\inetpub\pandahrms\performance\.next\static
xcopy /E /I Pandahrms-Performance\public C:\inetpub\pandahrms\performance\public
```

### 3.3 Configure Environment

Create a `.env` file in each deployment directory.

**SSO** (`C:\inetpub\pandahrms\sso\.env`):

```env
BASE_URL=http://localhost/sso
API_URL=http://localhost/api
PRODUCT_NAME=Pandahrms SSO
PRODUCT_SLOGAN=Single Sign-On Platform
VENDOR=pandaworks
```

**Performance** (`C:\inetpub\pandahrms\performance\.env`):

```env
API_BASE_URL=http://localhost/api
SSO_BASE_URL=http://localhost/sso
APP_BASE_URL=http://localhost/performanceV2
SESSION_PASSWORD=your-unique-session-password-here-32bytes
```

### 3.4 Register as Windows Service

Install node-windows globally:

```powershell
npm install -g node-windows
```

For each Next.js app, create a `service.js` file in the deployment directory:

**SSO** (`C:\inetpub\pandahrms\sso\service.js`):

```javascript
var Service = require("node-windows").Service;

var svc = new Service({
  name: "Pandahrms SSO",
  description: "Pandahrms Identity Server / SSO",
  script: "C:\\inetpub\\pandahrms\\sso\\server.js",
});

svc.on("install", function () {
  svc.start();
});

svc.install();
```

**Performance** (`C:\inetpub\pandahrms\performance\service.js`):

```javascript
var Service = require("node-windows").Service;

var svc = new Service({
  name: "Pandahrms Performance",
  description: "Pandahrms Performance Management Frontend",
  script: "C:\\inetpub\\pandahrms\\performance\\server.js",
});

svc.on("install", function () {
  svc.start();
});

svc.install();
```

Also create `service_uninstall.js` for each (same structure but call `svc.uninstall()` instead).

Register and start each service:

```powershell
# In admin Command Prompt
cd C:\inetpub\pandahrms\sso
npm link node-windows
node service.js

cd C:\inetpub\pandahrms\performance
npm link node-windows
node service.js
```

### 3.5 Create IIS Reverse Proxy

Create IIS web applications that proxy to the Node.js services:

| Alias | Points to | Node.js port |
|-------|-----------|-------------|
| `sso` | `http://localhost:3000` | 3000 |
| `performanceV2` | `http://localhost:3001` | 3001 |

For each, create a `web.config` with URL Rewrite rules to proxy requests to the Node.js service.

### 3.6 Verify Services

Open Task Manager > Services tab and confirm the Node.js services are running:
- "Pandahrms SSO"
- "Pandahrms Performance"

---

## Step 4: Configure Pandahrms Web

Update the Pandahrms web.config to point to the new services:

```xml
<appSettings>
    <add key="ApiBaseUrl" value="http://localhost/api" />
    <add key="IdentityServerBaseUrl" value="http://localhost/sso" />
</appSettings>
```

---

## Step 5: Verify Everything

1. Browse to the Pandahrms URL - you should be redirected to SSO for login
2. After login, verify you can access the main application
3. Test API endpoints via the gateway
4. Verify Performance frontend loads at its URL

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 500.19 error in IIS | Check ASP.NET Core Hosting Bundle is installed, run `iisreset` |
| 502.5 error | Check appsettings.json connection string and app pool settings |
| Node service won't start | Check service.js script path uses double backslashes |
| ARR not proxying | Verify "Enable proxy" is checked in ARR settings |
| Cannot connect to SQL Server | Verify SQL Server is running and accepting TCP/IP connections |

## Uninstalling Services

To remove the Node.js Windows services:

```powershell
cd C:\inetpub\pandahrms\sso
node service_uninstall.js

cd C:\inetpub\pandahrms\performance
node service_uninstall.js
```
