# style-guide.md

## Purpose

A token-first style guide template to unify design across all platforms. It outlines core design tokens, component patterns, microcopy, and accessibility guidelines for a consistent user experience.

## How to Update

Update **Design Tokens** first when adjusting colors, typography, or spacing – components inherit from tokens for consistency. Revise component sections only as needed to reflect new patterns; token changes propagate throughout components.

## Design Tokens

### Color

Token | Light | Dark | Usage  
{{COLOR_PRIMARY}} | `#TBD` | `#TBD` | Primary action background.  
{{COLOR_BACKGROUND}} | `#TBD` | `#TBD` | App background color.

- **Typography:** Primary `{{FONT_PRIMARY}}` font. Define a type scale (H1–H6, Body, etc.) with defined sizes and line-heights and limited font weights Light/Regular/Bold. Support multiple languages (RTL included).
- **Spacing & Layout:** Base spacing unit `{{SPACING_BASE}}px` for spacing (use multiples). Define responsive breakpoints `{{KEY_BREAKPOINTS}}` and a {{GRID_COLUMNS}}-column grid.
- **Radius & Elevation:** Consistent corner radii via tokens; apply uniformly across components. Define shadow tokens for elevation and use higher levels for modals/overlays.
- **Motion:** Tokenize animation durations (short, medium, long) and easing curves (enter/exit transitions). Keep animations subtle; honor prefers-reduced-motion settings (disable non-essential motion if requested).
- **Iconography & Imagery:** Use a consistent icon set (uniform style on a {{ICON_GRID}}px grid; base size {{ICON_BASE}}px). Use optimized images; include descriptive alt text for meaningful graphics.

## Component Guidance

### Button

- **Purpose:** Triggers an action.
- **Do:** Short, specific action labels
- **Don’t:** Generic labels

### Input & Textarea

- **Purpose:** Single or multi-line text input.
- **Do:** A clear label or placeholder; allow resizing/expanding for multi-line
- **Don’t:** Placeholder text as the only label

### Select

- **Purpose:** Select one option from a list.
- **Do:** Clearly show the selected option; support keyboard navigation
- **Don’t:** Present an ungrouped long list of options

### Card

- **Purpose:** Group related content.
- **Do:** Group related info
- **Don’t:** Overload it with content

### Modal/Dialog

- **Purpose:** Modal overlay for important content.
- **Do:** Include a title and a close button
- **Don’t:** Modal for trivial content

### Tooltip

- **Purpose:** Contextual info tip.
- **Do:** Keep the text short
- **Don’t:** Rely on tooltip for essential info or actions

### Toast/Alert

- **Purpose:** Show a brief or persistent message.
- **Do:** Keep messages concise
- **Don’t:** Obscure important UI

### Navbar/Sidebar

- **Purpose:** Primary navigation.
- **Do:** Highlight the current page or section
- **Don’t:** Overcrowd with too many links

### Table/List

- **Purpose:** Display structured data or list items.
- **Do:** Distinct header style
- **Don’t:** Tiny text or tight spacing

## Microcopy & Tone

- **Tone & Style:** Clear, inclusive language; use sentence case for UI text; follow locale-specific formats for numbers and dates.
- **Errors:** Politely explain what went wrong and how to fix it.

## Accessibility

- **Focus & Color:** Visible focus outlines on controls; ~44px hit targets; no color-only cues.
- **Semantics:** Use proper roles and labels; support screen reader and keyboard navigation.

## References

- WCAG 2.2; WAI-ARIA APG; Platform HIGs; Plain Language Guide; Inclusive Design Principles
