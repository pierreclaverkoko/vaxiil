# Design System Specification: Editorial Vitality

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Living Editorial."** 

This system moves beyond the sterile, utilitarian grids of standard wellness apps to create an experience that feels curated, rhythmic, and alive. We achieve this through a "High-End Editorial" lens: using intentional asymmetry, overlapping elements that break container boundaries, and a sophisticated play between deep, shadowy forests and misty morning light. 

By leveraging high-contrast typography scales and tonal depth, we transform the UI into a series of digital spreads rather than mere functional screens. The goal is to make the user feel as if they are leafing through a premium wellness journal—one that breathes with them.

---

## 2. Colors
Our palette is rooted in the natural world, utilizing a range of greens to define hierarchy and "Sunset Orange" to spark movement.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders for sectioning or containment. Boundaries must be defined solely through:
- **Background Color Shifts:** Placing a `surface-container-low` (#f1f5f2) card on a `surface` (#f6faf7) background.
- **Tonal Transitions:** Using soft shadows or gradients to indicate where one thought ends and another begins.

### Surface Hierarchy & Nesting
Treat the UI as physical layers of fine, handmade paper. 
- **Base Layer:** `surface` (#f6faf7) for the primary background.
- **Floating Context:** Use `surface-container-lowest` (#ffffff) for high-importance cards to make them appear "lifted" by light.
- **Recessed Context:** Use `surface-container-high` (#e5e9e6) for utility areas like search bars or inactive list backgrounds.

### Signature Textures & Gradients
Flat color is the enemy of premium design. 
- **The "Lush Gradient":** For Hero blocks and primary CTAs, use a linear gradient transitioning from `primary_container` (#1B5E20) to `primary` (#00450d) at a 135-degree angle. This creates a "forest floor" depth.
- **Glassmorphism:** Use semi-transparent surface colors (e.g., `surface` at 80% opacity) with a `20px backdrop-blur` for floating navigation bars or modal overlays.

---

## 3. Typography: Plus Jakarta Sans
We utilize **Plus Jakarta Sans** for its geometric clarity and modern editorial flair. The scale is designed to create a clear "Voice" for the content.

*   **Display (lg/md/sm):** Used for large, expressive hero moments. *Designer Note: Use tight letter-spacing (-0.02em) for Display sizes to achieve a high-fashion look.*
*   **Headline (lg/md/sm):** The primary storyteller. Headlines should often be center-aligned or intentionally offset to break the grid.
*   **Title (lg/md/sm):** Reserved for card headings and section titles. 
*   **Body (lg/md/sm):** Standardized for readability. Use `on-surface-variant` (#41493e) for secondary body text to reduce visual noise.
*   **Label (md/sm):** All-caps with a 0.05em letter-spacing for badges and small UI metadata.

---

## 4. Elevation & Depth: Tonal Layering
We reject the standard "Material" shadow. Elevation is a feeling, not a drop-shadow.

*   **The Layering Principle:** Depth is achieved by stacking surface tiers. A `surface-container-lowest` card sitting on a `surface-container` section provides a soft, natural lift.
*   **Ambient Shadows:** When a true "float" is required (e.g., a floating action button), use an extra-diffused shadow: `Offset: 0, 12px | Blur: 32px | Color: #181d1b at 6% opacity`.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline-variant` (#c0c9bb) at **15% opacity**. Never use 100% opaque lines.
*   **Physicality:** Objects should feel like they have mass. Use the full roundness (`9999px`) on interactive elements to mimic river stones—smooth, tactile, and organic.

---

## 5. Components

### Buttons
*   **Primary:** High-contrast `primary_container` (#1B5E20) background with `on_primary` (#ffffff) text. Full roundness.
*   **Secondary (Sunset Orange):** Use `secondary` (#964900) for micro-interactions and high-priority call-to-action "sparks." This color is a spice—use it sparingly.
*   **Tertiary:** Ghost style. No background, `primary` text, and a subtle scale-up effect on hover.

### Chips & Badges
*   **Filter Chips:** `surface-container-highest` (#dfe3e1) background with `on_surface` text. When selected, transition to the Lush Gradient.
*   **Status Badges:** Use `secondary_container` (#fc820c) with `on_secondary_container` (#5e2c00) for warm, urgent notifications.

### Cards & Lists
*   **The Divider Forfeiture:** Forbid the use of divider lines. Separate list items using `16px` or `24px` of vertical white space or by alternating background tints (`surface` vs `surface-container-low`).
*   **Overlapping Imagery:** Allow images (like food or botanical elements) to break out of the card container (negative margins). This adds "Pulse" to the layout.

### Input Fields
*   **Style:** Minimalist. `surface-container-high` background, no border, full roundness. 
*   **Active State:** A subtle `1px` ghost border using `primary` at 20% opacity.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts where text is left-aligned and imagery is right-aligned, partially overlapping.
*   **Do** prioritize "Misty Sage" (`background` #f6faf7) for large whitespace areas to keep the vibe airy.
*   **Do** use the "Sunset Orange" for small, delightful micro-interactions (e.g., a heart icon pulse or a "New" notification dot).

### Don't
*   **Don't** use black (#000000) for text. Always use `on-surface` (#181d1b) to maintain a soft, organic feel.
*   **Don't** use standard "Box Shadows." If the layer doesn't feel separated enough, increase the background color contrast instead.
*   **Don't** cram content. If a screen feels full, increase the artboard height. This design system requires "oxygen" to function effectively.