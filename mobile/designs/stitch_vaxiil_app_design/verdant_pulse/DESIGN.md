# Design System Specification: Editorial Wellness

## 1. Overview & Creative North Star
**Creative North Star: "The Living Sanctuary"**

This design system moves away from the sterile, clinical nature of traditional SaaS platforms toward a "soft health" editorial experience. It is designed to feel like a premium wellness magazine—intentional, airy, and restorative. We break the "standard template" look by utilizing extreme corner radii, organic layering, and a "No-Line" philosophy. The layout logic is driven by "The Appetite Principle": elements are not boxed in; they are nestled within one another, creating a tactile, physical depth that mimics high-end stationery or frosted glass layers.

## 2. Colors & Surface Philosophy
The palette is rooted in a monochromatic sage-to-forest spectrum to reduce cognitive load and induce a sense of calm.

*   **Primary High-Contrast (`#0d631b`):** Reserved for authoritative text and primary actions.
*   **Secondary/Mints (`#c8e6c9`, `#cceacd`):** Used for large pill-shaped CTAs and interactive surfaces.
*   **The "No-Line" Rule:** Explicitly prohibit the use of 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. For example, a `surface-container-low` (`#ecf7eb`) element should sit on a `background` (`#f1fcf1`) without a stroke.
*   **Surface Hierarchy & Nesting:** Use the surface-container tiers to create "stacked" depth. 
    *   *Lowest:* Background base.
    *   *High/Highest:* Interactive cards or critical modals.
*   **The Glass & Gradient Rule:** For hero sections or floating navigation, use Glassmorphism (backdrop-blur: 20px) combined with semi-transparent `surface` colors. Main CTAs should utilize a subtle linear gradient from `primary` (`#0d631b`) to `primary_container` (`#2e7d32`) to provide a "soulful" depth rather than a flat, plastic look.

## 3. Typography
We use **Plus Jakarta Sans** (the modern evolution of Poppins style) to maintain a clean, approachable, and premium editorial feel.

*   **Display & Headlines:** Use `display-lg` (3.5rem) with tight letter-spacing (-0.02em) for hero moments. This conveys authority and modern elegance.
*   **Title & Body:** `title-md` (1.125rem) is used for card headers to ensure readability against soft backgrounds. `body-lg` (1rem) serves as the workhorse for all wellness content.
*   **The Label Intent:** `label-md` and `label-sm` are specifically for metadata and "pill" text, always set in medium or semi-bold weights to maintain legibility at small scales.

## 4. Elevation & Depth
In this system, depth is a feeling, not a shadow effect. We prioritize **Tonal Layering** over traditional drop shadows.

*   **The Layering Principle:** Physicality is achieved by stacking. A `surface-container-lowest` (#ffffff) card placed on a `surface-container` (#e6f1e6) background creates a natural lift.
*   **Ambient Shadows:** When a floating effect is mandatory (e.g., a floating action button), use "Ambient Light" shadows: `box-shadow: 0 20px 40px rgba(20, 30, 23, 0.06)`. The shadow must be a tinted version of the `on-surface` color, never pure black.
*   **Ghost Borders:** If a boundary is required for accessibility, use a "Ghost Border": the `outline-variant` token at 15% opacity. High-contrast borders are strictly forbidden.
*   **The Pill Motif:** All interactive containers must use the `xl` (3rem) or `full` (9999px) roundedness scale to mimic the Vaxiil logo's organic curves.

## 5. Components

### Buttons & Pills
*   **Primary CTA:** Pill-shaped (`rounded-full`), using the Mint Primary Container (`#c8e6c9`) with `on-primary-fixed-variant` text.
*   **Secondary Action:** Ghost style with a `surface-variant` background transition on hover.

### Floating Navigation
*   **Bottom Bar:** Rather than a full-width bar, use a floating "dock" with `xl` (3rem) corner radius, a subtle backdrop blur, and `surface-container-highest` background.

### Cards & Data Lists
*   **Zero-Divider Rule:** Forbid the use of divider lines. Separate list items using `vertical white space` (16px–24px) or subtle background shifts (e.g., alternating between `surface-container-low` and `surface-container-lowest`).
*   **Card Composition:** Following the Appetite App example, cards should feature overlapping imagery (e.g., a circular image mask partially breaking the top boundary of the card) to create a three-dimensional feel.

### Input Fields
*   **Form Style:** Use "Soft Fields"—backgrounds in `surface-container-highest` with no border. On focus, transition the background to `surface-lowest` and apply a 2px "Ghost Border" in `primary`.

## 6. Do's and Don'ts

### Do:
*   **Use Asymmetry:** Place imagery and text in off-center compositions to create an editorial, high-end feel.
*   **Embrace White Space:** Give typography room to breathe. Use "over-sized" padding (32px+) inside cards.
*   **Layer Containers:** Nest a white card inside a light green section to create focus.

### Don't:
*   **Don't Use 1px Strokes:** Avoid "boxing in" the user. Let the colors define the space.
*   **Don't Use Sharp Corners:** Anything under 28px (`lg` scale) is too aggressive for this brand. 
*   **Don't Over-Shadow:** If you can see the shadow clearly, it’s too dark. It should feel like a soft glow/mist.
*   **Don't Use Pure Greys:** All neutrals must be tinted with green (Sage/Forest) to maintain the "Soft Health" atmosphere.