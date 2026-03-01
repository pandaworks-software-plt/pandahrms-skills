---
name: react-web-frontend
description: Use when building features, components, or pages in any PandaHRMS Next.js web project (Pandahrms-Performance, Pandahrms-Recruitment, pandahrms-sso), or when unsure about frontend naming, page patterns, state management, or component architecture
---

# React Web Frontend

## Overview

Shared conventions for all PandaHRMS Next.js 15 web projects. Performance project is the reference standard.

**Announce at start:** "I'm using the react-web-frontend skill for frontend conventions."

**Applies to:** Pandahrms-Performance, Pandahrms-Recruitment, pandahrms-sso

**Does NOT apply to:** pandaworks-app (mobile), Pandahrms_Web (MVC5)

## Feature-Driven Architecture

```
src/
├── app/                    # Next.js pages (thin layer - delegate to features)
├── features/
│   ├── _commons/           # Shared across features
│   └── [feature]/          # Self-contained domain module
│       ├── actions/        # Server actions
│       ├── components/     # Feature-specific UI
│       ├── hooks/          # Feature hooks
│       ├── lib/            # Utilities
│       ├── schemas/        # Zod validation
│       ├── services/       # API calls
│       ├── stores/         # Zustand state
│       └── types/          # Types
├── components/ui/          # shadcn components ONLY
├── lib/
│   ├── api-client/types.ts # Auto-generated (never edit, regenerate with pnpm generate-api)
│   └── queryKeys/          # TanStack Query key factories
└── stores/                 # Global Zustand stores
```

**Rules:**
- API calls in `services/` or `actions/` only - never in components
- `components/ui/` for shadcn only - custom components go in feature `components/` or `_commons/components/`
- Auto-generated `types.ts` - never edit manually

## State Management

| Tool | Use For |
|------|---------|
| Zustand | Global app state, localStorage persistence |
| TanStack Query | Server state with caching |
| react-hook-form + Zod | Form state and validation |
| nuqs | URL search params sync |

## Component Naming

Names must be **descriptive and intent-revealing**. Structure: [Data] + [Action] + [Type]

```tsx
// BAD
AppraisalReportsPageImproved, DataTableV2, UserFormNew, ButtonBetter, ComponentFinal

// GOOD
AppraisalDataExportView, SortableDataTable, UserRegistrationForm, PrimaryActionButton
```

**Never use:** `*Improved`, `*Better`, `*New`, `*Old`, `*V2`, `*V3`, `*Final`, `*Real`, `*Temp`

**Exception:** Version suffixes acceptable during major rewrites (e.g., `appraisal-form-v2`) - remove after migration.

## File Naming

| Type | Convention | Example |
|------|-----------|---------|
| Components | PascalCase | `EmployeeCard.tsx` |
| Utils/Helpers | kebab-case | `column-extractor.ts` |
| Services | kebab-case | `appraisal-cycles.services.ts` |
| Actions | kebab-case | `session.actions.ts` |
| Feature dirs | kebab-case | `kpi-setting/` |

## Function and Variable Naming

- **Services:** verb + noun - `getAppraisals`, `updateKpiSettings`
- **Handlers:** `handle` + action - `handleSubmit`, `handleColumnReorder`
- **Booleans:** `is/has/should` prefix - `isLoading`, `hasChanges`
- **Arrays:** plural - `appraisals`, `selectedColumns`
- **Constants:** UPPER_SNAKE_CASE - `MAX_RETRIES`, `DEFAULT_PAGE_SIZE`

## Page Hierarchy

### Listing Page
```
Container
├── PageHeader (title, subtitle, icon, actions)
└── PageContent
    ├── Filters (FilterBar + SearchInput)
    └── data-list
```

### Detail Page
```
Container
├── PageHeader (title, icon, back navigation)
└── PageContent
    └── DetailView component
```

### Tabbed Page
```
Container (layout)
├── PageHeader (title, actions)
├── TabHeader
└── {children}
```

## Component Layers (max 3 deep)

1. **Wrapper** - Client component receiving server data
2. **Pure Component** - Presentational, focused props
3. **Atom** - ui / common components

```tsx
// BAD - passing entire object
<EmployeeCard employee={employee} />

// GOOD - pass only needed fields
<EmployeeCard name={employee.name} department={employee.department} />
```

## SSR Data Flow

- `page.tsx` fetches data server-side via `services/`
- Pass data as props to client components
- Extract business logic to `lib/` (rules, calculations)
- Complex state -> custom hook (`use*.ts`)

## Code Standards

- **Formatter:** Biome (2-space indent, 120-char lines, single quotes)
- **TypeScript:** NEVER use `any` - use proper types, `unknown`, or generics
- **Dark mode:** Always use `dark:` variants (next-themes enabled)
- **No IIFE:** Use named functions, direct assignments, or early returns
- **No emojis:** Anywhere (code, comments, UI, commits)
- **Icons:** Lucide only (`lucide-react`)
- **data-list:** Always use for rendering data items; content must fit viewport

## i18n (next-intl)

- Define defaults in `src/features/i18n/lib/preset-translations.ts`
- No inline fallbacks: use preset file, not `t('key') || 'fallback'`

## Testing

- **Stack:** Vitest + @testing-library/react in `__tests__/` directories
- Test files need `import React from 'react'` for JSX despite linter warnings
- Always verify by running tests, not just static analysis

## Verification

**Use `pnpm lint` or `pnpm lint:fix`. NEVER `pnpm build`** (too slow, unnecessary for most changes).

## Product Design

Enterprise HR system - reference Workday, SAP SuccessFactors, Oracle HCM for UX patterns:
- Standard HR terminology ("performance cycle", "calibration")
- Audit trails, role-based access, multi-level approval workflows
- Design for complex org structures (matrix, multiple reporting lines)
