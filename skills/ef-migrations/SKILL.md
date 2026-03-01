---
name: ef-migrations
description: Use when creating, applying, undoing, or troubleshooting Entity Framework Core migrations in any Pandahrms .NET backend project (Performance API, Recruitment API), or when you need to generate SQL scripts from migrations
---

# EF Core Migrations

## Overview

Run EF Core migration commands for Pandahrms backend APIs. Each API has its own Persistence project with DbContext-specific migrations.

**Announce at start:** "I'm using the ef-migrations skill to manage database migrations."

## Project Reference

| API Project | Persistence Project Path | DbContext | Audit DbContext |
|-------------|--------------------------|-----------|-----------------|
| Pandahrms_PerformanceApi | `Pandahrms.Performance.Persistence/` | `PerformanceDbContext` | `AuditDbContext` |
| Pandahrms_RecruitmentApi | `Pandahrms.Recruitment.Persistence/` | `RecruitmentDbContext` | `AuditDbContext` |

**Important:** All commands must be run from inside the Persistence project directory, not the solution root.

## Commands

### Add a Migration

Creates a new migration file based on model changes.

```bash
cd <PersistenceProjectPath>
dotnet ef migrations add <MigrationName> --context <DbContextName>
```

**Example:**
```bash
cd Pandahrms.Performance.Persistence/
dotnet ef migrations add AddNewColumn --context PerformanceDbContext
```

**Naming convention:** Use PascalCase describing the change. Examples:
- `AddEmployeeAppraisalForm`
- `RefactorAssessment`
- `ChangeDataTypeForScore`
- `RemoveDeprecatedColumn`

### Apply Migrations (Update Database)

Applies all pending migrations to the database.

```bash
dotnet ef database update --context <DbContextName>
```

**Example:**
```bash
dotnet ef database update --context PerformanceDbContext
```

### List Migrations

Shows all migrations and their applied status.

```bash
dotnet ef migrations list --context <DbContextName>
```

**Example:**
```bash
dotnet ef migrations list --context PerformanceDbContext
```

### Undo Last Migration (Not Applied)

Removes the last migration file if it has NOT been applied to the database.

```bash
dotnet ef migrations remove --context <DbContextName>
```

### Rollback to a Specific Migration

Reverts the database to a specific migration. All migrations after it are undone.

```bash
dotnet ef database update <TargetMigrationName> --context <DbContextName>
```

**Example:**
```bash
dotnet ef database update RefactorAssessment --context PerformanceDbContext
```

### Rollback All Migrations

Reverts ALL migrations, returning the database to its initial state.

```bash
dotnet ef database update 0 --context <DbContextName>
```

### Generate SQL Script

Generates a SQL script for a range of migrations. Useful for production deployments.

```bash
dotnet ef migrations script <FromMigration> <ToMigration> --context <DbContextName> --output <OutputPath>
```

**Examples:**
```bash
# Script from one migration to another
dotnet ef migrations script AddNewColumn RefactorAssessment --context PerformanceDbContext --output ./migration-script.sql

# Script from a migration back to zero (undo script)
dotnet ef migrations script AddNewColumn 0 --context PerformanceDbContext --output ./undo-script.sql
```

## Workflow

### Adding a new migration

1. Make entity/model changes in the Core project
2. `cd` into the Persistence project
3. Run `dotnet ef migrations add <Name> --context <DbContext>`
4. Review the generated migration file in `Migrations/<DbContext>/`
5. Run `dotnet ef database update --context <DbContext>`
6. Verify the database changes

### Undoing a mistake

1. If migration is NOT applied: `dotnet ef migrations remove --context <DbContext>`
2. If migration IS applied: `dotnet ef database update <PreviousMigration> --context <DbContext>`, then `dotnet ef migrations remove --context <DbContext>`

## Safety Rules

- Always review generated migration files before applying
- Never edit a migration that has already been applied to a shared database
- When undoing, rollback the database FIRST, then remove the migration file
- For production, generate SQL scripts instead of running `database update` directly
