---
name: Radiance Aesthetic
colors:
  surface: '#fcf9f8'
  surface-dim: '#dcd9d9'
  surface-bright: '#fcf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f0eded'
  surface-container-high: '#eae7e7'
  surface-container-highest: '#e5e2e1'
  on-surface: '#1c1b1b'
  on-surface-variant: '#57423b'
  inverse-surface: '#313030'
  inverse-on-surface: '#f3f0ef'
  outline: '#8b7169'
  outline-variant: '#dec0b6'
  surface-tint: '#a43c12'
  primary: '#a43c12'
  on-primary: '#ffffff'
  primary-container: '#ff7f50'
  on-primary-container: '#6c2000'
  inverse-primary: '#ffb59c'
  secondary: '#821dda'
  on-secondary: '#ffffff'
  secondary-container: '#9c42f4'
  on-secondary-container: '#fffbff'
  tertiary: '#78555e'
  on-tertiary: '#ffffff'
  tertiary-container: '#c399a3'
  on-tertiary-container: '#50313a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbcf'
  primary-fixed-dim: '#ffb59c'
  on-primary-fixed: '#380c00'
  on-primary-fixed-variant: '#822800'
  secondary-fixed: '#efdbff'
  secondary-fixed-dim: '#dcb8ff'
  on-secondary-fixed: '#2c0051'
  on-secondary-fixed-variant: '#6700b5'
  tertiary-fixed: '#ffd9e2'
  tertiary-fixed-dim: '#e7bbc6'
  on-tertiary-fixed: '#2d141c'
  on-tertiary-fixed-variant: '#5e3e47'
  background: '#fcf9f8'
  on-background: '#1c1b1b'
  surface-variant: '#e5e2e1'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  container-padding: 24px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
  gutter: 16px
---

## Brand & Style

The design system is built for an aspirational AI-driven skincare experience targeting Gen Z and Millennials. The brand personality is "The Digital Dermatologist Friend"—expert yet approachable, modern, and high-energy. It moves away from sterile, clinical environments into a "glow-up" aesthetic that feels more like a premium lifestyle magazine or a high-end beauty ritual.

The visual style is **Glassmorphism mixed with Modern Minimalism**. It utilizes soft backdrop blurs and semi-transparent layers to suggest light passing through healthy skin. The interface should feel breathable, airy, and "dewy," mirroring the desired physical results of the product. High-end editorial influence is visible in the large, confident typography and generous negative space.

## Colors

The palette is anchored by a vibrant **"Aura Gradient"** (Coral to Violet), representing transformation and energy. This gradient should be used sparingly for primary actions, progress indicators, and active states to maintain its impact.

The background is never pure white; it uses a soft, fleshy **"Dewy Base"** gradient (Peachy-pink to Lavender) at very low opacity to create warmth and depth. 
- **Primary:** Coral (#FF7F50) – warmth and vitality.
- **Secondary:** Violet (#8A2BE2) – technology and premium quality.
- **Neutral:** Deep Charcoal (#1A1A1A) for text to ensure high legibility against soft backgrounds.
- **Surface:** White (#FFFFFF) with 70-80% opacity for glassmorphic elements.

## Typography

This design system uses **Inter** exclusively to maintain a clean, systematic, yet friendly feel. The hierarchy relies on extreme scale contrast. 

Large "Display" sizes are used for skin scores and welcome headings, often featuring tight letter-spacing to feel more editorial. Body text is kept spacious to ensure the "premium" feel isn't cluttered. Use `label-md` in all caps for small category tags to add a structured, professional touch to the organic layout.

## Layout & Spacing

The layout follows a **fluid mobile-first grid** optimized for the iPhone 15 aspect ratio. 
- **Margins:** A standard 24px horizontal margin provides a spacious, high-end feel.
- **Rhythm:** An 8px linear scale governs all vertical spacing.
- **Safe Areas:** Ensure all critical "Scan" actions are within the bottom-middle thumb zone, utilizing floating action buttons to maintain the glassmorphic layering.
- **Sectioning:** Use white space rather than lines to separate content blocks, ensuring the "glow" of the background is visible.

## Elevation & Depth

Depth is achieved through **Glassmorphism and Ambient Shadows** rather than traditional elevation levels.
- **Glass Sheets:** Main content containers use a background blur (Backdrop Filter: blur(20px)) and a subtle 1px inner white border (semi-transparent) to simulate the edge of a glass pane.
- **Soft Shadows:** Use a "Natural Bloom" shadow: `0px 10px 30px rgba(138, 43, 226, 0.08)`. The shadows should be slightly tinted with the secondary violet color to maintain the vibrant aesthetic.
- **Z-Axis:** The camera preview sits at the lowest level, with glass cards floating above it, creating a sense of augmented reality.

## Shapes

The design system utilizes **extreme roundedness** to evoke a sense of softness and safety. 
- **Cards & Modals:** Use a fixed 20px (1.25rem) corner radius.
- **Buttons:** Use fully pill-shaped (rounded-full) corners to emphasize the "friendly/lifestyle" aspect.
- **Input Fields:** Match the card radius (20px) to maintain a cohesive container language.
- **Scanning Reticle:** Should be a continuous "Squircle" shape rather than a standard circle or square to feel more modern and organic.

## Components

- **Primary Buttons:** High-contrast pill shapes using the "Aura Gradient." Text is white, bold, and centered. Include a soft glow shadow that matches the gradient.
- **Glass Cards:** Semi-transparent white background (opacity 0.7) with a 20px blur. Used for health stats, routine tips, and AI analysis results.
- **Skin Progress Chips:** Small, pill-shaped indicators with subtle background tints (e.g., a light green tint for "Improving").
- **Analysis Overlays:** Technical data (like pore density or hydration levels) should appear as floating "hotspots" on the face scan, connected by thin, 1px lines to glass labels.
- **Input Fields:** Filled with a very faint white-alpha (0.5), 20px radius, and a 1px border that glows into the primary gradient color when focused.
- **Progress Rings:** Used for "Skin Score," featuring the Aura Gradient with a rounded cap stroke to feel liquid and smooth.