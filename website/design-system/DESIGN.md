# Apple — Style Reference
> Polished lens on innovation — clear, precise, and understated.

**Theme:** light / dark (auto)

The Apple design system exudes a precise, almost ethereal clarity, like a perfectly polished lens focusing on content. Impeccable kerning and tracking, especially in headlines, create an understated authority. A subtle hierarchy of grays defines surfaces without heavy shadows, anchored by a vibrant yet contained blue for interaction. Product imagery is the hero, framed by minimal UI that gets out of the way.

---

## Tokens — Colors

| Name | Value | Token | Role |
|------|-------|-------|------|
| Midnight Graphite | `#1d1d1f` | `--color-midnight-graphite` | Primary text, headline text, glyphs, and navigation elements. |
| Deep Gray | `#333333` | `--color-deep-gray` | Secondary text and navigation elements. |
| Charcoal Grey | `#474747` | `--color-charcoal-grey` | Link text and navigation link text. |
| Medium Gray | `#86868b` | `--color-medium-gray` | Tertiary text, footer text, subtle UI elements. |
| Light Gray | `#a1a1a6` | `--color-light-gray` | Muted text, icon fills. |
| Light Silver | `#c7c7c7` | `--color-light-silver` | Subtle image box shadows. |
| Border Silver | `#d2d2d7` | `--color-border-silver` | Thin, crisp border lines for UI separation. |
| Lightest Gray Background | `#e2e2e5` | `--color-lightest-gray-background` | Subtle background for UI components. |
| Canvas White | `#f5f5f7` | `--color-canvas-white` | Dominant page background. |
| Pure White | `#ffffff` | `--color-pure-white` | Elevated UI elements, nav backgrounds. |
| True Black | `#000000` | `--color-true-black` | Icon fills and headline accents. |
| Interactive Blue | `#0071e3` | `--color-interactive-blue` | Primary interactive element background, buttons, focus rings. |
| Action Blue | `#0066cc` | `--color-action-blue` | Link color for interactive text and outline buttons. |
| Sky Blue Highlight | `#2997ff` | `--color-sky-blue-highlight` | Vivid blue for interactive states, hover links. |
| Cerulean Shine | `#3397d4` | `--color-cerulean-shine` | Secondary accent for graphic elements. |
| Pale Blue Overlay | `#9fc6f4` | `--color-pale-blue-overlay` | Soft background for content sections. |
| Vibrant Orange | `#ec893c` | `--color-vibrant-orange` | Product/promotional accent. |
| Deep Plum | `#7424b5` | `--color-deep-plum` | Content block accent (e.g. Apple TV). |
| Blush Pink | `#ea33c0` | `--color-blush-pink` | Playful branding accent. |
| Warm Taupe | `#604630` | `--color-warm-taupe` | Themed section background. |
| Cool Teal | `#32ade6` | `--color-cool-teal` | Cool modern accent. |

### Dark Mode Colors

| Name | Value | Token | Role |
|------|-------|-------|------|
| Dark Base | `#161617` | `--color-dark-base` | Primary dark mode background. |
| Dark Elevated | `#1c1c1e` | `--color-dark-elevated` | Cards, sheets, elevated surfaces. |
| Dark Secondary | `#2c2c2e` | `--color-dark-secondary` | Secondary grouped background. |
| Dark Tertiary | `#3a3a3c` | `--color-dark-tertiary` | Tertiary grouped background. |
| Dark Text Primary | `#f5f5f7` | `--color-dark-text-primary` | Primary text on dark. |
| Dark Text Secondary | `#86868b` | `--color-dark-text-secondary` | Secondary text on dark. |
| Dark Text Tertiary | `#a1a1a6` | `--color-dark-text-tertiary` | Tertiary text on dark. |
| Dark Border | `#424245` | `--color-dark-border` | Borders in dark mode. |

---

## Tokens — Typography

### SF Pro Text — Primary typeface for body text, UI labels, buttons, navigation, and footer content.
- **Weights:** 300, 400, 500, 600
- **Sizes:** 12px, 14px, 17px, 19px
- **Letter spacing:** -0.01em to -0.022em
- **Role:** Body copy, UI labels, buttons, navigation, footer.

### SF Pro Display — Headlines and display-sized text.
- **Weights:** 400, 600, 700
- **Sizes:** 21px, 24px, 28px, 32px, 40px, 48px, 56px, 64px, 80px, 96px
- **Letter spacing:** -0.021em to -0.04em
- **OpenType features:** `"numr"`
- **Role:** Headlines, display text, hero copy.

### Type Scale

| Role | Size | Line Height | Letter Spacing | Token |
|------|------|-------------|----------------|-------|
| caption | 12px | 1.33 | -0.01em | `--text-caption` |
| body-sm | 14px | 1.4286 | -0.016em | `--text-body-sm` |
| body | 17px | 1.4706 | -0.022em | `--text-body` |
| subheading | 19px | 1.21 | -0.021em | `--text-subheading` |
| callout | 21px | 1.19 | -0.021em | `--text-callout` |
| heading-sm | 24px | 1.1667 | -0.021em | `--text-heading-sm` |
| heading-md | 28px | 1.14 | -0.021em | `--text-heading-md` |
| heading-lg | 32px | 1.125 | -0.021em | `--text-heading-lg` |
| display-sm | 40px | 1.1 | -0.022em | `--text-display-sm` |
| display-md | 48px | 1.083 | -0.024em | `--text-display-md` |
| display-lg | 56px | 1.07 | -0.028em | `--text-display-lg` |
| display-xl | 64px | 1.0625 | -0.03em | `--text-display-xl` |
| display-xxl | 80px | 1.05 | -0.036em | `--text-display-xxl` |
| display-giant | 96px | 1.04 | -0.04em | `--text-display-giant` |

**Critical:** Apple uses `em` units for letter spacing on the web, not `px`. This ensures scaling fidelity.

---

## Tokens — Spacing & Shapes

**Base unit:** 4px

**Density:** comfortable

### Spacing Scale

| Name | Value | Token |
|------|-------|-------|
| 4 | 4px | `--spacing-4` |
| 8 | 8px | `--spacing-8` |
| 12 | 12px | `--spacing-12` |
| 16 | 16px | `--spacing-16` |
| 20 | 20px | `--spacing-20` |
| 24 | 24px | `--spacing-24` |
| 28 | 28px | `--spacing-28` |
| 32 | 32px | `--spacing-32` |
| 36 | 36px | `--spacing-36` |
| 40 | 40px | `--spacing-40` |
| 48 | 48px | `--spacing-48` |
| 52 | 52px | `--spacing-52` |
| 64 | 64px | `--spacing-64` |
| 72 | 72px | `--spacing-72` |
| 80 | 80px | `--spacing-80` |
| 96 | 96px | `--spacing-96` |
| 120 | 120px | `--spacing-120` |

### Border Radius

| Element | Value | Token |
|---------|-------|-------|
| cards | 0px | `--radius-cards` |
| lists | 999px | `--radius-lists` |
| images | 11px | `--radius-images` |
| inputs | 8px | `--radius-inputs` |
| buttons | 980px | `--radius-buttons` |

### Shadows

| Name | Value | Token |
|------|-------|-------|
| sm | `0 1px 2px rgba(0,0,0,0.04)` | `--shadow-sm` |
| md | `0 4px 16px rgba(0,0,0,0.08)` | `--shadow-md` |
| lg | `0 12px 32px rgba(0,0,0,0.12)` | `--shadow-lg` |
| xl | `rgba(0,0,0,0.22) 3px 5px 30px 0px` | `--shadow-xl` |
| product | `0 18px 40px rgba(0,0,0,0.14)` | `--shadow-product` |

### Layout

- **Section gap:** 80px (standard), 120px (large)
- **Card padding:** 15px
- **Element gap:** 10px
- **Content max-width:** 980px (standard), 1024px (large)
- **Breakpoints:** 734px, 1068px, 1440px

---

## Components

### Primary Filled Button
Solid Interactive Blue background (#0071e3) with Pure White text (#ffffff), 980px pill radius. Padding 11px vertical, 21px horizontal. Font 17px / weight 400. Hover: #0077ed.

### Outline Link Button
Transparent background with Action Blue text (#0066cc), 1px Action Blue border. Same 980px pill radius, 11px vertical / 21px horizontal padding.

### Text Link Button
Transparent background, Sky Blue Highlight text (#2997ff). No border or radius. Padding 0px for inline use.

### Navigation Bar
Glass material: `backdrop-filter: saturate(180%) blur(20px)`. Light: `rgba(255,255,255,0.72)`. Dark: `rgba(29,29,31,0.72)`. Height ~44px. Links at 14px / weight 400.

### Product Section Hero
Full-width. Headlines in SF Pro Display (56px–96px, weight 600) on Canvas White. Large product imagery below headline. Generous vertical padding (80px–120px).

### Featured Content Card
Transparent background, 0px radius, no shadow. Full-bleed content. Often uses unique background colors or imagery.

---

## Do's and Don'ts

### Do
- Use **em units** for letter spacing (`-0.022em`), not px, for web scalability.
- Prioritize SF Pro Display for headlines (21px+) with tight tracking.
- Use SF Pro Text for all body copy, UI labels, and navigation.
- Apply 980px border-radius for all pill buttons.
- Use Interactive Blue (#0071e3) for filled buttons, Sky Blue (#2997ff) for links.
- Maintain hierarchy: Midnight Graphite → Medium Gray → Light Gray.
- Implement dark mode with `#161617` base and `#f5f5f7` text.
- Use `backdrop-filter: saturate(180%) blur(20px)` for nav glassmorphism.
- Keep body text at 17px with line-height 1.4706.

### Don't
- Don't use px values for letter spacing on web — use em.
- Don't deviate from pill-shape radius for buttons.
- Don't forget dark mode — Apple has full dark mode support.
- Don't use harsh drop shadows — use subtle layered shadows or background shifts.
- Don't introduce decorative borders around primary content blocks.
- Don't use generic system default link styles.

---

## Surfaces

| Level | Name | Light Value | Dark Value | Purpose |
|-------|------|-------------|------------|---------|
| 0 | Canvas | `#f5f5f7` | `#161617` | Dominant page background. |
| 1 | Elevated | `#ffffff` | `#1c1c1e` | Nav backgrounds, content blocks. |
| 2 | Secondary | `#e2e2e5` | `#2c2c2e` | Grouped components. |
| 3 | Tertiary | `#d2d2d7` | `#3a3a3c` | Recessed areas. |

## Elevation & Glass

- **Nav Glass Light:** `rgba(255, 255, 255, 0.72)` + `saturate(180%) blur(20px)`
- **Nav Glass Dark:** `rgba(29, 29, 31, 0.72)` + `saturate(180%) blur(20px)`
- **Product Image Card:** `rgba(0, 0, 0, 0.22) 3px 5px 30px 0px`

## Animations

| Name | Curve | Duration | Use |
|------|-------|----------|-----|
| Standard | `cubic-bezier(0.4, 0, 0.2, 1)` | 300ms | Hover, opacity, color |
| Emphasis | `cubic-bezier(0.65, 0, 0.35, 1)` | 500ms | Scale, transform |
| Bounce | `cubic-bezier(0.34, 1.56, 0.64, 1)` | 400ms | Pop-in, micro-interactions |

## Imagery

Product-centric, highly polished. Isolated product shots on clean backgrounds. Monochromatic iconography in Midnight Graphite or True Black. Fine stroke weight. Minimal lifestyle photography.

## Layout

Max-width contained layout (980px) with full-bleed hero sections. Centered headline stacks. Large product images dominate visual field. Sticky top navigation. Spacious vertical rhythm.

## Agent Prompt Guide

Quick Color Reference:
- Text Primary: #1d1d1f (light) / #f5f5f7 (dark)
- Background Canvas: #f5f5f7 (light) / #161617 (dark)
- Call To Action: #0071e3
- Border/Divider: #d2d2d7 (light) / #424245 (dark)
- Link: #2997ff

Example Prompts:
1. Hero section: Canvas White background. Headline 'iPhone' at 80px SF Pro Display weight 600, #1d1d1f, tracking -0.036em. Subhead at 28px SF Pro Text weight 400. Two pill buttons with 10px gap. Product image below.
2. Navigation: Glass material `saturate(180%) blur(20px)`, light rgba(255,255,255,0.72). Links at 14px SF Pro Text weight 400, #1d1d1f. Apple logo icon #000000.
3. Dark mode section: #161617 background. Headline at 56px SF Pro Display weight 600, #f5f5f7. Subtitle at 21px SF Pro Text weight 400, #86868b.

## Similar Brands
- **Google** — Clean, bright UI, ample whitespace, single brand color.
- **Samsung** — Product-forward imagery, neutral palette, single accent.
- **Microsoft** — Systematic typography, clean lines, strong hierarchy.
- **Linear** — Clinical attention to typography details, minimalist aesthetic.
