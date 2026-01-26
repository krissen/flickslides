#!/bin/bash
# Bygger och deployar FlickSlides på alla tre plattformar
# Användning: ./scripts/run-all.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/Apps/FlickSlides.xcodeproj"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# Enhetsnamn och ID (anpassa vid behov)
IPHONE_NAME="anandavani"
WATCH_NAME="Apple Watch för Kristian"
WATCH_ID="00008301-C082B1342E0BC02E"

echo "🔨 Bygger och deployar FlickSlides..."
echo ""

# Bygg Mac-appen
echo "📦 Mac..."
xcodebuild -project "$PROJECT" \
    -scheme FlickSlides \
    -configuration Debug \
    -destination 'platform=macOS' \
    build 2>&1 | tail -5

# Hitta och starta Mac-appen (exkludera Index.noindex)
MAC_APP=$(find "$DERIVED_DATA" -name "FlickSlidesMac.app" -path "*/Build/Products/Debug/*" -not -path "*/Index.noindex/*" -type d 2>/dev/null | head -1)
if [ -n "$MAC_APP" ] && [ -f "$MAC_APP/Contents/MacOS/FlickSlidesMac" ]; then
    # Stäng ev. körande version först
    pkill -x FlickSlidesMac 2>/dev/null || true
    sleep 0.5
    echo "   Startar Mac-app..."
    open "$MAC_APP"
else
    echo "   ⚠️  Mac-app hittades inte"
fi

echo ""
echo "📱 Phone..."
xcodebuild -project "$PROJECT" \
    -scheme FlickSlidesPhone \
    -configuration Debug \
    -destination "platform=iOS,name=$IPHONE_NAME" \
    build 2>&1 | tail -5

# Installera på iPhone
echo "   Installerar på iPhone..."
PHONE_APP=$(find "$DERIVED_DATA" -name "FlickSlidesPhone.app" -path "*/Debug-iphoneos/*" -type d 2>/dev/null | head -1)
if [ -n "$PHONE_APP" ]; then
    xcrun devicectl device install app --device "$IPHONE_NAME" "$PHONE_APP" 2>/dev/null || true
    xcrun devicectl device process launch --device "$IPHONE_NAME" com.kristianniemi.FlickSlides 2>/dev/null || true
fi

echo ""
echo "⌚ Watch..."
xcodebuild -project "$PROJECT" \
    -scheme FlickSlidesWatch \
    -configuration Debug \
    -destination "platform=watchOS,id=$WATCH_ID" \
    build 2>&1 | tail -5

# Installera på Watch
WATCH_APP=$(find "$DERIVED_DATA" -name "FlickSlidesWatch.app" -path "*/Debug-watchos/*" -not -path "*/Index.noindex/*" -type d 2>/dev/null | head -1)
if [ -n "$WATCH_APP" ]; then
    echo "   Installerar på Watch..."
    xcrun devicectl device install app --device "$WATCH_NAME" "$WATCH_APP" 2>/dev/null && echo "   ✓ Installerad" || echo "   ⚠️  Installera manuellt via Xcode"
else
    echo "   ⚠️  Watch-app hittades inte"
fi

echo ""
echo "✅ Klart!"
