# Docker Deployment

Local development setup using Docker Compose. Runs the full Pandahrms stack in containers with a single command.

## What This Sets Up

Docker Compose orchestrates these services on a shared network:

| Service | Container | Host Port | Description |
|---------|-----------|-----------|-------------|
| API Gateway | pandahrms-api-gateway | 8080 | Ocelot reverse proxy - routes API requests to the correct backend |
| SQL Server | pandahrms-sqlserver | 1433 | SQL Server 2022 database (Developer edition) |
| Main API | pandahrms-api | 8010 | Core Pandahrms .NET API |
| Performance API | pandahrms-performance-api | 8011 | Performance module .NET API |
| Recruitment API | pandahrms-recruitment-api | 8012 | Recruitment module .NET API |
| Performance FE | pandahrms-performance | 8001 | Performance frontend (Next.js) |
| SSO | pandahrms-sso | 8000 | Identity/SSO frontend (Next.js) |

## Prerequisites

### Docker Desktop

**What it is:** Docker Desktop provides the Docker engine and Docker Compose for running containerized applications. Each service runs in its own isolated container.

**Check:** `docker --version && docker compose version`

**Install:**
- macOS: `brew install --cask docker` then launch Docker Desktop from Applications
- Windows: `winget install Docker.DockerDesktop` then launch Docker Desktop

**Verify:** `docker info` (should show server info without errors)

Ensure Docker Desktop is running before proceeding.

## Step 1: Configure Environment

The Docker setup lives in the `_docker/` directory at the workspace root.

```bash
cd _docker
cp .env.example .env
```

Open `.env` and configure these variables:

### Database

| Variable | Description | Default |
|----------|-------------|---------|
| `CONNSTRING` | SQL Server connection string | `Server=sqlserver;Database=hcm_dev;...` |
| `SA_PASSWORD` | SQL Server SA password | `YourStrong@Password123` |

The default connection string points to the dockerized SQL Server. Change it only if using an external database.

### API Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `JWT_TOKEN_KEY` | JWT signing key - MUST be identical across all APIs | (provided in .env.example) |
| `CORS_ALLOWED_ORIGINS` | Comma-separated allowed origins | `http://localhost:8001,http://localhost:8000` |
| `ASPNETCORE_ENVIRONMENT` | .NET environment | `Development` |

### SSO Frontend

| Variable | Description | Default |
|----------|-------------|---------|
| `CORE_API_BASE_URL` | Internal API URL (container-to-container) | `http://pandahrms-api:8080` |
| `NEXT_PUBLIC_CORE_API_BASE_URL` | Public API URL (browser access) | `http://localhost:8080` |
| `PRODUCT_NAME` | SSO branding name | `Pandahrms SSO` |
| `PRODUCT_SLOGAN` | SSO branding slogan | `Single Sign-On Platform` |
| `VENDOR` | Vendor name | `pandaworks` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `FLAG_MOBILE_APP_SETUP` | Show mobile app setup in SSO | `false` |
| `VERBOSE_LOGGING` | Enable detailed logging | `false` |

## Step 2: Build and Start

From the `_docker/` directory:

```bash
docker compose up -d --build
```

**What this does:**
- Builds Docker images for each service using their respective Dockerfiles
- Creates a shared `pandahrms-network` bridge network
- Creates a `sqlserver-data` persistent volume for the database
- Starts all containers in the background (`-d`)
- Services start in dependency order (SQL Server first, then APIs, then frontends)

First build takes several minutes as it downloads base images and builds each project.

## Step 3: Verify Containers

Check that all containers are running and healthy:

```bash
docker compose ps
```

All services should show status `Up` with health status `healthy`. SQL Server takes about 60 seconds to become healthy.

To view logs for a specific service:

```bash
docker compose logs -f pandahrms-api
```

## Step 4: Database Setup

If this is a fresh setup, you may need to create or restore the database:

**Option A: Restore from backup**
Place your `.bak` file in `_docker/backup/`, then restore:

```bash
docker exec -it pandahrms-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong@Password123" -C \
  -Q "RESTORE DATABASE hcm_dev FROM DISK='/var/opt/mssql/backup/your-backup.bak' WITH REPLACE"
```

**Option B: Connect with a SQL client**
Connect to `localhost:1433` with SA credentials using Azure Data Studio, SSMS, or any SQL client.

## Common Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Rebuild a specific service
docker compose up -d --build pandahrms-api

# View logs
docker compose logs -f

# Restart a specific service
docker compose restart performance-api

# Remove everything (including volumes - WARNING: deletes database data)
docker compose down -v
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Container keeps restarting | Check logs: `docker compose logs <service>` |
| Port already in use | Stop the conflicting service or change ports in `docker-compose.yml` |
| SQL Server not healthy | Wait 60s for startup, check SA_PASSWORD meets complexity requirements |
| Build fails | Ensure Docker Desktop has enough resources (4GB+ RAM recommended) |
| macOS ARM (M1/M2/M3) | SQL Server runs via `platform: linux/amd64` emulation - this is normal |
