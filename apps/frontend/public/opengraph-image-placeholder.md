# OpenGraph Image Placeholder

This directory should contain the OpenGraph image for social media sharing.

## Creating icon.png (OpenGraph Image)

OpenGraph images should be **1200x630 pixels** for optimal display on social media platforms (Twitter, Facebook, LinkedIn, etc.).

### Option 1: Using ImageMagick
```bash
# Convert SVG to PNG with proper dimensions
cd apps/frontend/public
convert ../app/icon.svg -resize 1200x630 -gravity center -extent 1200x630 icon.png
```

### Option 2: Using Inkscape
```bash
inkscape ../app/icon.svg --export-filename=icon.png --export-width=1200 --export-height=630
```

### Option 3: Using Online Tool
1. Go to https://cloudconvert.com/svg-to-png
2. Upload `app/icon.svg`
3. Set dimensions to 1200x630px
4. Download as `icon.png` and place in `public/`

### Option 4: Design Custom OpenGraph Image
For better social media appearance, create a custom image with:
- Dimensions: 1200x630px
- Format: PNG or JPG
- Include: Logo, tagline, brand colors
- Keep important content in the center (safe zone)

## File Purpose

- **File**: `public/icon.png`
- **Used for**: OpenGraph and Twitter Card images
- **Referenced in**: `lib/metadata.ts`
- **Size**: 1200x630px recommended

This image appears when your site is shared on social media platforms.
