# Apple Design System Audit

**Audited:** 2026-05-14  
**Source files:** `tokens.json`, `variables.css`, `theme.css`, `DESIGN.md`  
**Target:** `website/` (Next.js 15 + Tailwind CSS v4)

---

## 🚨 Critical Bugs

### 1. Malformed Hex Color — `cool-teal`
**Your value:** `#485b5` (5 digits, invalid CSS)  
**Corrected:** `#32ade6` (Apple's actual teal accent)

This would cause a CSS parse error and break any component using that token.

---

## ⚠️ Major Gaps

### 2. No Dark Mode Tokens
Apple.com has full `prefers-color-scheme: dark` support. Your files contain **zero** dark mode colors. Apple uses:
- Background: `#161617`
- Elevated: `#1c1c1e`
- Text: `#f5f5f7`
- Borders: `#424245`

**Impact:** Any user with dark mode enabled sees a blinding light page. This is a massive Apple fidelity break.

### 3. No Glassmorphism / Elevation Tokens
Apple's nav uses a specific material:  
`backdrop-filter: saturate(180%) blur(20px)` with `rgba(255,255,255,0.72)`

Your tokens don't capture this at all.

### 4. Missing Typography Sizes
Apple's web typography scale includes sizes you omitted:
- **17px** — Apple's standard body copy (you had this in `tokens.json` but not in CSS files)
- **19px** — Subheadings
- **32px** — Large headings
- **48px, 64px, 80px, 96px** — Hero display sizes

### 5. Letter Spacing in `px` Instead of `em`
Apple's web CSS uses **em units** for letter spacing (`-0.022em`), not px (`-0.22px`). Em scales with font-size; px does not. This causes tracking to look wrong at larger sizes.

**Your value:** `-0.22px`  
**Apple's value:** `-0.021em` (equivalent at 16px, but scales correctly)

### 6. Outdated Grays
Apple shifted their gray palette on the web:

| Your Value | Modern Apple Value | Token |
|------------|-------------------|-------|
| `#707070` | `#86868b` | medium-gray |
| `#858585` | `#a1a1a6` | light-gray |
| `#d6d6d6` | `#d2d2d7` | border-silver |

Your values feel slightly "muddier" than Apple's current crisp grays.

### 7. Missing Animation Tokens
Apple's motion language is iconic. Missing:
- `cubic-bezier(0.4, 0, 0.2, 1)` — standard ease
- `cubic-bezier(0.65, 0, 0.35, 1)` — emphasis ease
- Duration values: 150ms, 300ms, 500ms

### 8. Incomplete Spacing Scale
Apple uses a strict 4px grid. Your scale stops at 52px. Missing:
- 4px, 28px, 32px, 36px, 64px, 72px, 80px, 96px, 120px

### 9. Missing Semantic Tokens
You only have **primitive** colors (raw hex values). Apple uses **semantic** aliases:
- `--text-primary`, `--text-secondary`, `--bg-primary`, `--bg-elevated`

This makes theming and dark mode impossible.

### 10. Missing Breakpoints
Apple's web breakpoints are well-known: **734px**, **1068px**, **1440px**. Not in your tokens.

---

## ✅ What Was Good

| Item | Status |
|------|--------|
| `#1d1d1f` primary text | ✅ Correct |
| `#f5f5f7` canvas | ✅ Correct |
| `#0071e3` interactive blue | ✅ Correct |
| `#ffffff` pure white | ✅ Correct |
| `#000000` true black | ✅ Correct |
| 4px base grid unit | ✅ Correct |
| 980px pill radius | ✅ Correct |
| SF Pro font families | ✅ Correct |
| 8px image radius | ✅ Close (Apple uses 11px now) |

---

## 📁 Files Written

| File | Path | Description |
|------|------|-------------|
| `globals.css` | `website/app/globals.css` | **Your live theme file** — fully corrected with Tailwind v4 `@theme inline`, dark mode, glassmorphism, animations |
| `tokens.json` | `website/design-system/tokens.json` | W3C design tokens with dark mode, animations, breakpoints |
| `variables.css` | `website/design-system/variables.css` | CSS custom properties with semantic aliases + dark mode |
| `theme.css` | `website/design-system/theme.css` | Tailwind v4 `@theme` block (non-inline) reference |
| `DESIGN.md` | `website/design-system/DESIGN.md` | Updated design reference documentation |

---

## 🛠️ Recommended Next Steps

1. **Review `website/app/globals.css`** — this is now your single source of truth.
2. **Update components** to use semantic tokens (e.g., `bg-primary` instead of `bg-canvas-white`) so dark mode works automatically.
3. **Add `dark:` variants** in Tailwind classes where needed, or rely on the CSS `prefers-color-scheme` in `globals.css`.
4. **Test letter spacing** — the switch from px to em will make headlines feel tighter and more "Apple" at large sizes.
5. **Verify nav blur** — use the `.nav-blur` utility class; it now has the correct `saturate(180%)` value.
