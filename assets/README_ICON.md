# EduVerse App Icon Setup

## Required Files

You need to create TWO image files in this `assets` folder:

### 1. `app_icon.png` (REQUIRED)
- **Size**: 1024 x 1024 pixels (minimum)
- **Format**: PNG with no transparency
- **Design**: Your full logo with background
- This will be used for:
  - Android app icon
  - iOS app icon  
  - Web favicon
  - Windows icon
  - macOS icon

### 2. `app_icon_foreground.png` (REQUIRED for Android Adaptive Icons)
- **Size**: 1024 x 1024 pixels
- **Format**: PNG with transparent background
- **Design**: Just the icon/symbol (no background)
- The background color will be your blue (#1565C0)

## Your Current Logo Design

Based on your splash screen, your logo is:
- A white rounded square container
- With a blue school/graduation cap icon inside
- Primary color: #1A237E (Deep Indigo)

## How to Create Your Icon

### Option 1: Use Icon Kitchen (Recommended - Free & Easy)
1. Go to https://icon.kitchen/
2. Upload an image or choose a clipart (search for "school" or "graduation")
3. Set background color to #1565C0
4. Download the icon pack
5. Use the 1024px version

### Option 2: Use Canva (Free)
1. Go to https://canva.com
2. Create a new design (1024 x 1024 px)
3. Add blue background (#1565C0)
4. Add a white school/education icon
5. Download as PNG

### Option 3: Use Figma (Free)
1. Create a 1024x1024 frame
2. Add your design
3. Export as PNG

## After Creating the Icons

Run this command in your terminal:

```bash
flutter pub run flutter_launcher_icons
```

This will automatically generate all the required icon sizes for:
- Android (all mipmap folders)
- iOS (all App Icon sizes)
- Web (favicon and PWA icons)
- Windows
- macOS

## Verify Your Icons

After running the command, check:
- `web/favicon.png` - Web browser tab icon
- `web/icons/` - PWA icons
- `android/app/src/main/res/mipmap-*/` - Android launcher icons
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` - iOS app icons
