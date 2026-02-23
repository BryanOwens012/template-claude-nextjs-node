# Favicon Placeholder

For a production application, you should create actual favicon.ico and apple-icon.png files.

## Creating favicon.ico

### Option 1: Using ImageMagick
```bash
# Convert SVG to ICO (multiple sizes)
convert icon.svg -define icon:auto-resize=16,32,48 favicon.ico
```

### Option 2: Using Online Tool
1. Go to https://favicon.io/ or https://realfavicongenerator.net/
2. Upload your `icon.svg` or design
3. Download the generated `favicon.ico`
4. Place in `app/` directory

## Creating apple-icon.png

Apple touch icons should be 180x180 pixels:

```bash
# Using ImageMagick
convert icon.svg -resize 180x180 apple-icon.png
```

## File Placement (Next.js App Router Convention)

Place these files directly in the `app/` directory:
- `app/favicon.ico` - Automatically detected by Next.js
- `app/icon.svg` - Vector icon (already included)
- `app/apple-icon.png` - For iOS home screen

Keep in `public/` for OpenGraph images:
- `public/icon.png` - 1200x630px for social media sharing

Next.js will automatically generate the appropriate `<link>` tags in the `<head>`.
