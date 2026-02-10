#!/bin/bash
set -e

APP_PATH="$1"
IDENTITY="$2"
ENTITLEMENTS="$3"

echo "📦 Signing App: $APP_PATH"
echo "🆔 Identity: $IDENTITY"
echo "📄 Entitlements: $ENTITLEMENTS"

if [ -z "$APP_PATH" ] || [ -z "$IDENTITY" ]; then
    echo "Usage: sign_app.sh <App Path> <Identity> [Entitlements Path]"
    exit 1
fi

# 1. Clean attributes
echo "🧹 Cleaning extended attributes..."
xattr -cr "$APP_PATH"

# 2. Find all signable items depth-first
# Order matters: Deepest components must be signed first.
# We look for: frameworks, apps, xpc services, bundles, app extensions, dylibs, so
echo "🔍 Scanning for components to sign..."

# Use find with -depth (BSD/macOS) to ensure children are processed before parents
# We exclude symlinks (-type l) to avoid signing the same component multiple times via different paths
# Also explicitly find Autoupdate binaries inside Sparkle
find "$APP_PATH" -depth \
    \( -name "*.framework" -o -name "*.app" -o -name "*.xpc" -o -name "*.bundle" -o -name "*.appex" -o -name "*.dylib" -o -name "*.so" -o -name "Autoupdate" \) \
    ! -path "$APP_PATH" \
    ! -type l \
    | while read -r item; do
    
    echo "✍️  Signing component: $item"
    
    # Determine options based on file type
    # Add --timestamp for Notarization requirement
    OPTS="--force --verbose --timestamp --sign \"$IDENTITY\" --options runtime"
    
    # Only apply entitlements to App Extensions (and the main app later)
    # For Sparkle components (Updater.app, XPC), we use default entitlements (no flag)
    # We DO NOT preserve metadata to ensure a clean signature with our Team ID
    if [[ "$item" == *.appex ]]; then
        if [ -n "$ENTITLEMENTS" ]; then
            OPTS="$OPTS --entitlements \"$ENTITLEMENTS\""
        fi
    fi
    
    # Execute signing
    # We use eval to handle the quoted Identity string correctly
    # Note: Sparkle.framework requires deep signing
    if [[ "$item" == *.framework ]]; then
       OPTS="$OPTS --deep"
    fi
    eval codesign $OPTS "\"$item\""
done

# 3. Sign the Main App
echo "✍️  Signing Main App..."
OPTS="--force --verbose --timestamp=none --sign \"$IDENTITY\" --options runtime"
if [ -n "$ENTITLEMENTS" ]; then
    OPTS="$OPTS --entitlements \"$ENTITLEMENTS\""
fi
eval codesign $OPTS "\"$APP_PATH\""

# 4. Verify Signature
echo "✅ Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
