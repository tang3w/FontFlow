# FontFlow — Phase 1 Development Plan

## Goal

Build the must-have foundation: a credible, usable font manager that lets users import fonts, browse them beautifully, organize them, activate/deactivate reliably, detect problems, and group fonts by project.

## Guiding Principles

- **Simple over clever.** Prefer straightforward AppKit patterns. Avoid abstraction layers that don't pay for themselves yet.
- **Core Text is the engine.** Apple's Core Text framework (`CTFont`, `CTFontDescriptor`, `CTFontManager`) provides font parsing, metadata, rendering, and activation. Lean on it heavily.
- **Core Data is the store.** The persistent container is already wired up. Define entities carefully once; keep the schema normalized but not over-relational.
- **Build vertically.** Each milestone delivers a working slice of the app, not a horizontal layer.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│                    AppDelegate                    │
│          (Core Data stack, app lifecycle)         │
├──────────────────────────────────────────────────┤
│                  MainSplitVC                      │
│    ┌──────────┬──────────────┬───────────────┐   │
│    │ Sidebar  │  Font List   │  Detail /     │   │
│    │  (src)   │  (table)     │  Preview      │   │
│    └──────────┴──────────────┴───────────────┘   │
├──────────────────────────────────────────────────┤
│  Services                                        │
│  ┌────────────┐ ┌────────────┐ ┌──────────────┐ │
│  │ FontImport │ │ FontActiv. │ │  FontHealth  │ │
│  │  Service   │ │  Service   │ │   Service    │ │
│  └────────────┘ └────────────┘ └──────────────┘ │
├──────────────────────────────────────────────────┤
│  Core Data Model                                 │
│  FontRecord · FontFamily · Tag · Collection ·    │
│  ProjectSet · SmartFilter                        │
└──────────────────────────────────────────────────┘
```

**UI**: Three-column `NSSplitViewController` — sidebar for navigation, center for the font list, trailing for preview/comparison. All defined in `Main.storyboard`.

**Services**: Plain Swift classes that encapsulate business logic. No protocol-heavy abstractions. Each service receives an `NSManagedObjectContext` where needed.

---

## Core Data Model

Design the schema first — everything depends on it.

### Entities

| Entity | Key Attributes | Notes |
|---|---|---|
| **FontRecord** | `id` (UUID), `postScriptName`, `displayName`, `familyName`, `styleName`, `filePath`, `bookmarkData` (Binary), `fileSize` (Int64), `isActivated` (Bool), `isFavorite` (Bool), `lastUsedDate` (Date?), `importedDate` (Date), `isValid` (Bool), `duplicateGroupID` (UUID?) | One record per font face. `bookmarkData` stores a security-scoped bookmark for sandbox-safe re-access. |
| **FontFamily** | `name` (String), `id` (UUID) | Groups FontRecords that share a family name. Relationship: `fonts` ↔ `family` (one-to-many). |
| **Tag** | `id` (UUID), `name` (String), `color` (String?) | User-created labels. Many-to-many with FontRecord. |
| **Collection** | `id` (UUID), `name` (String), `createdDate` (Date), `sortOrder` (Int16) | Manual grouping. Many-to-many with FontRecord. |
| **ProjectSet** | `id` (UUID), `name` (String), `clientName` (String?), `createdDate` (Date), `lastActivatedDate` (Date?), `sortOrder` (Int16) | Project-scoped font group. Many-to-many with FontRecord. |

### Relationships

- `FontRecord.family` → `FontFamily` (many-to-one)
- `FontRecord.tags` ↔ `Tag.fonts` (many-to-many)
- `FontRecord.collections` ↔ `Collection.fonts` (many-to-many)
- `FontRecord.projectSets` ↔ `ProjectSet.fonts` (many-to-many)

### Rationale

- Smart filters are **not** persisted as entities in Phase 1. They are predefined `NSPredicate` queries (e.g. "Activated", "Favorites", "Recently Added", "Duplicates"). This avoids over-designing. User-defined smart filters can be added later.
- `bookmarkData` enables re-accessing imported font files across app launches under App Sandbox without re-prompting the user.

---

## Milestones

### M1 — Core Data Model & Font Metadata Reader

**What**: Define the Core Data schema and build a service that reads font metadata from a file URL using Core Text.

**Deliverables**:
- Core Data model (`.xcdatamodeld`) with all entities and relationships above.
- `FontMetadataReader` — a struct/class that takes a file `URL` and returns parsed metadata (family name, style, PostScript name, supported scripts, variable axes, etc.) using `CTFontCreateWithGraphicsFont` / `CTFontDescriptor`.
- Unit tests for `FontMetadataReader` with sample font files.

**Key APIs**: `CTFontManagerCreateFontDescriptorsFromURL`, `CTFontDescriptorCopyAttribute`, `CTFontCopyVariationAxes`.

---

### M2 — Import Pipeline

**What**: Let users add font files/folders to the library. Parse, deduplicate, and persist.

**Deliverables**:
- `FontImportService` — accepts file URLs, reads metadata via `FontMetadataReader`, creates `FontRecord` and `FontFamily` entries in Core Data, generates security-scoped bookmarks.
- Support for `.ttf`, `.otf`, `.ttc`, `.otc`, `.woff`, `.woff2` (whatever Core Text accepts).
- Duplicate detection during import: match on PostScript name + file hash. Mark duplicates with a shared `duplicateGroupID`.
- Progress reporting (closure/delegate callback) for large imports.
- Sandbox entitlement update: change user-selected-files to `read-write` if needed, or keep `read-only` since we're not modifying originals.
- Unit tests for import logic (creating records, detecting duplicates).

**Dependencies**: M1.

---

### M3 — Main UI Shell

**What**: Build the three-column layout and wire it to Core Data with basic navigation.

**Deliverables**:
- `MainSplitViewController` (`NSSplitViewController`) set as the window's content controller in the storyboard.
- **Sidebar** (`SidebarViewController`): outline view with sections — Library (All Fonts, Favorites, Recently Added), Collections, Project Sets, Tags. Powered by a static/dynamic data source.
- **Font List** (`FontListViewController`): `NSTableView` (or `NSCollectionView` for grid mode) showing font names with a small preview. Backed by `NSFetchedResultsController` (or manual fetch + `NSArrayController`).
- **Detail Pane** (`FontDetailViewController`): placeholder for preview (built in M4).
- Selection flow: tap sidebar item → update fetch predicate on font list → select font → show detail.
- Toolbar with a search field (`NSSearchField`), view-mode toggle (list/grid), and an import button.

**Dependencies**: M1 (needs the model to display).

---

### M4 — Preview & Comparison

**What**: Render fonts beautifully. Support custom sample text, adjustable size, and side-by-side comparison.

**Deliverables**:
- `FontPreviewView` — custom `NSView` that renders sample text using `NSAttributedString` with the selected font. Supports configurable sample text, font size slider, and line spacing.
- Variable font support: if a font has variation axes (`CTFontCopyVariationAxes`), show sliders for each axis (weight, width, slant, etc.).
- Language/script preview: a dropdown of common scripts (Latin, Cyrillic, Arabic, CJK, etc.) with sample strings. Show glyph coverage indicator (percentage of glyphs present).
- **Comparison mode**: select 2–4 fonts, display them stacked or side-by-side in the detail pane. Shared sample text and size controls.
- Basic font metadata display: family, style, format, file size, glyph count, supported scripts.

**Dependencies**: M3 (needs the detail pane to host the preview).

---

### M5 — Search & Organization

**What**: Tags, collections, smart filters, favorites, and full-text search.

**Deliverables**:
- **Search**: filter the font list by typing in the toolbar search field. Match against `displayName`, `familyName`, `styleName`, `postScriptName`, and tag names. Use `NSPredicate` compound queries on Core Data.
- **Tags**: create/delete tags from sidebar. Assign/remove tags via context menu or drag-and-drop onto sidebar tag items. Tag colors (small circle swatch).
- **Collections**: create/rename/delete from sidebar. Add fonts via drag-and-drop or context menu. Reorder with `sortOrder`.
- **Smart Filters** (predefined, not user-editable in Phase 1):
  - All Fonts
  - Favorites
  - Recently Added (last 7 days)
  - Recently Used (last 7 days)
  - Activated
  - Duplicates (where `duplicateGroupID` is not nil)
  - Variable Fonts
- **Favorites**: toggle via toolbar star button or context menu. Persisted as `isFavorite` on `FontRecord`.

**Dependencies**: M3 (needs sidebar and list UI), M2 (needs fonts in the database).

---

### M6 — Activation & Deactivation

**What**: Activate/deactivate fonts system-wide so they appear in other apps.

**Deliverables**:
- `FontActivationService` — wraps `CTFontManagerRegisterFontsForURL` / `CTFontManagerUnregisterFontsForURL` with proper scope (`.user`).
- Persist activation state in `FontRecord.isActivated`. Restore on app launch (re-register activated fonts using stored bookmarks).
- UI: activation toggle button in the font list row and detail pane. Clear status indicator (green dot = active, gray = inactive, red = error).
- Batch activation: activate/deactivate all fonts in a collection or project set with one click.
- Error handling: if activation fails (e.g., file moved, corrupted), surface a clear message and mark the font as invalid.
- Update `lastUsedDate` when a font is activated.

**Key APIs**: `CTFontManagerRegisterFontsForURL(_:_:_:)`, `CTFontManagerUnregisterFontsForURL(_:_:_:)`.

**Sandbox note**: Activating fonts from within the sandbox requires the font files to be accessible. Security-scoped bookmarks (stored in `bookmarkData`) must be resolved and started before registration.

**Dependencies**: M2 (needs imported fonts with bookmarks), M3 (needs UI).

---

### M7 — Font Health Tools

**What**: Help users find and resolve duplicate, conflicting, or broken fonts.

**Deliverables**:
- **Duplicate detection** (already partially done in M2 import): group fonts with matching PostScript name. Show a "Duplicates" smart filter in the sidebar. In the list, display duplicates grouped with visual indicators.
- **Conflict detection**: detect when an imported font has the same PostScript name as a system-installed or previously activated font. Warn the user before activation.
- **Validation**: attempt to create a `CTFont` from each record; if it fails, mark `isValid = false`. Show an "Issues" smart filter for invalid fonts.
- **Health dashboard** (optional, simple): a summary view accessible from the sidebar showing counts — total fonts, duplicates, conflicts, invalid. Not a complex UI, just a helpful overview.

**Dependencies**: M2 (needs imported data), M6 (activation status for conflict checks).

---

### M8 — Project Sets

**What**: Let users group fonts by project/client and activate a whole set at once.

**Deliverables**:
- CRUD for project sets: create, rename, delete from sidebar or a dedicated section.
- Add/remove fonts via drag-and-drop or context menu.
- **One-click activation**: activate all fonts in a project set. Deactivate the previous set if the user wants exclusive activation (optional toggle: "deactivate other projects on activate").
- Show `lastActivatedDate` and surface recently used project sets at the top of the sidebar section.
- `clientName` as optional metadata for organization.

**Dependencies**: M5 (sidebar organization), M6 (activation service).

---

## Milestone Dependency Graph

```
M1 (Model + Reader)
├── M2 (Import)
│   ├── M5 (Search & Organize)  ── needs fonts in DB
│   ├── M6 (Activation)         ── needs bookmarks
│   │   ├── M7 (Health)         ── needs activation status
│   │   └── M8 (Project Sets)   ── needs activation
│   └── M7 (Health)             ── needs imported data
└── M3 (UI Shell)
    ├── M4 (Preview)            ── needs detail pane
    ├── M5 (Search & Organize)  ── needs sidebar + list
    ├── M6 (Activation)         ── needs UI controls
    └── M8 (Project Sets)       ── needs sidebar
```

**Suggested build order**: M1 → M2 → M3 → M4 → M5 → M6 → M7 → M8

M4 and M5 can be developed in parallel once M3 is done. M7 and M8 can also be parallelized after M6.

---

## Sandbox & Entitlements Notes

The app already has App Sandbox and Hardened Runtime enabled. Key considerations:

- **File access**: Use `NSOpenPanel` to let users pick font files/folders. Store security-scoped bookmarks (`URL.bookmarkData(options: .withSecurityScope)`) in Core Data for persistent access.
- **Font activation**: `CTFontManagerRegisterFontsForURL` works within the sandbox when the app has access to the file (via bookmark or open panel).
- **Entitlement update needed**: The current entitlement is `read-only` for user-selected files. This is sufficient since we only read font files, not modify them.

---

## Testing Strategy

- **Unit tests** (Swift Testing): `FontMetadataReader`, `FontImportService`, `FontActivationService`, `FontHealthService`, Core Data model validation, search predicate logic.
- **UI tests** (XCTest): Import flow, activation toggle, sidebar navigation, search, project set creation.
- **Manual testing**: Use a collection of diverse fonts — variable fonts, CJK fonts, large families, corrupted files, duplicates — to verify real-world behavior.
- Include a few `.ttf`/`.otf` test fixtures in the test bundle for automated testing.

---

## What This Plan Deliberately Omits

These are **not** in Phase 1, per Mission.md and the principle of not over-designing:

- User-defined smart filters (predefined ones are enough to start)
- Drag-and-drop font installation from Finder (import via Open Panel is sufficient)
- Font file copying into an app-managed library (we reference originals via bookmarks)
- Undo/redo for organization actions (Core Data undo manager is available but wiring it up everywhere is deferred)
- Sync, collaboration, or any network features
- iPad or iPhone support
- Licensing metadata
- AI-powered features
