#!/bin/bash
set -e

APP_PATH="$1"
IDENTITY="$2"
ENTITLEMENTS="$3"

# Max retry attempts for codesign
MAX_RETRIES=3
RETRY_DELAY=5

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
# EXCLUDE: nested resource bundles (e.g., .bundle/Contents/Resources/*.bundle) which are not signable
find "$APP_PATH" -depth \
    \( -name "*.framework" -o -name "*.app" -o -name "*.xpc" -o -name "*.bundle" -o -name "*.appex" -o -name "*.systemextension" -o -name "*.dylib" -o -name "*.so" -o -name "Autoupdate" \) \
    ! -path "$APP_PATH" \
    ! -type l \
    ! -path "*/Contents/Resources/*.bundle" \
    | while read -r item; do
    
    echo "✍️  Signing component: $item"
    
    # Determine options based on file type
    # Add --timestamp for Notarization requirement
    # Add --preserve-metadata=identifier,entitlements,flags to keep original attributes (vital for Sparkle/Extensions)
    OPTS=(--force --verbose --timestamp --sign "$IDENTITY" --options runtime --preserve-metadata=identifier,entitlements,flags)
    
    # Attempt to extract existing entitlements
    ENTITLEMENTS_FILE=$(mktemp "${TMPDIR:-/tmp}/lumi-entitlements.XXXXXX.plist")
    
    # Try to dump entitlements to a file
    if codesign -d --entitlements - --xml "$item" > "$ENTITLEMENTS_FILE" 2>/dev/null; then
        # Check if file is not empty (it might be empty if no entitlements)
        if [ -s "$ENTITLEMENTS_FILE" ]; then
             echo "   Reuse existing entitlements for $(basename "$item")"
             OPTS+=(--entitlements "$ENTITLEMENTS_FILE")
        fi
    fi
    
    # Note: Sparkle.framework requires deep signing if we want to be safe,
    # but strictly speaking we should sign inside-out.
    # Since we are using find -depth, we are signing inside-out.
    # We REMOVE --deep to avoid double-signing or overwriting inner signatures with wrong flags.

    # Execute signing with retry logic
    retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if codesign "${OPTS[@]}" "$item" 2>&1; then
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo "   ⚠️  Signing failed (attempt $retry_count/$MAX_RETRIES), retrying in ${RETRY_DELAY}s..."
                sleep $RETRY_DELAY
            else
                echo "   ❌  Signing failed after $MAX_RETRIES attempts"
                exit 1
            fi
        fi
    done
    
    # Clean up
    rm -f "$ENTITLEMENTS_FILE"
done

# 3. Sign helper executables (bare binaries in Contents/Helpers/)
# These are standalone executables without bundle wrappers (e.g., LumiPreviewHostApp)
# that are not matched by the framework/bundle/extension find above.
echo "🔍 Signing helper executables..."
HELPERS_DIR="$APP_PATH/Contents/Helpers"
if [ -d "$HELPERS_DIR" ]; then
    find "$HELPERS_DIR" -type f ! -type l 2>/dev/null | while read -r helper; do
        if [ -x "$helper" ]; then
            echo "✍️  Signing helper: $helper"
            retry_count=0
            while [ $retry_count -lt $MAX_RETRIES ]; do
                if codesign --force --verbose --timestamp --sign "$IDENTITY" --options runtime "$helper" 2>&1; then
                    break
                else
                    retry_count=$((retry_count + 1))
                    if [ $retry_count -lt $MAX_RETRIES ]; then
                        echo "   ⚠️  Signing helper failed (attempt $retry_count/$MAX_RETRIES), retrying in ${RETRY_DELAY}s..."
                        sleep $RETRY_DELAY
                    else
                        echo "   ❌  Signing helper failed after $MAX_RETRIES attempts"
                        exit 1
                    fi
                fi
            done
        fi
    done
fi

# 4. Sign bare executables in Contents/MacOS
# These are standalone executables copied into the app after the target that
# builds them has finished (for example, the embedded lumi-acp runtime).
# They are not bundles, so the component scan above does not find them.
echo "🔍 Signing bare executables..."
MACOS_DIR="$APP_PATH/Contents/MacOS"
MAIN_EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)
if [ -d "$MACOS_DIR" ]; then
    find "$MACOS_DIR" -type f -perm -111 ! -type l ! -name "$MAIN_EXECUTABLE" 2>/dev/null | while read -r executable; do
        echo "✍️  Signing executable: $executable"
        retry_count=0
        while [ $retry_count -lt $MAX_RETRIES ]; do
            if codesign --force --verbose --timestamp --sign "$IDENTITY" --options runtime "$executable" 2>&1; then
                break
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $MAX_RETRIES ]; then
                    echo "   ⚠️  Signing executable failed (attempt $retry_count/$MAX_RETRIES), retrying in ${RETRY_DELAY}s..."
                    sleep $RETRY_DELAY
                else
                    echo "   ❌  Signing executable failed after $MAX_RETRIES attempts"
                    exit 1
                fi
            fi
        done
    done
fi

# 5. Sign the Main App
echo "✍️  Signing Main App..."
OPTS=(--force --verbose --timestamp --sign "$IDENTITY" --options runtime)
if [ -n "$ENTITLEMENTS" ]; then
    OPTS+=(--entitlements "$ENTITLEMENTS")
fi
retry_count=0
while [ $retry_count -lt $MAX_RETRIES ]; do
    if codesign "${OPTS[@]}" "$APP_PATH" 2>&1; then
        break
    else
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            echo "   ⚠️  Main app signing failed (attempt $retry_count/$MAX_RETRIES), retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        else
            echo "   ❌  Main app signing failed after $MAX_RETRIES attempts"
            exit 1
        fi
    fi
done

# 6. Verify Signature
echo "✅ Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Verify the embedded ACP runtime explicitly. A top-level app verification can
# otherwise miss a bare executable that was not included in the app's code
# signature hierarchy.
ACP_HELPER="$MACOS_DIR/lumi-acp"
if [ -f "$ACP_HELPER" ]; then
    codesign --verify --strict --verbose=2 "$ACP_HELPER"
    ACP_SIGNATURE=$(codesign -d --verbose=4 "$ACP_HELPER" 2>&1)
    if ! grep -q 'flags=.*runtime' <<< "$ACP_SIGNATURE"; then
        echo "❌ Embedded ACP helper is missing the hardened runtime"
        exit 1
    fi
    if ! grep -q '^Timestamp=' <<< "$ACP_SIGNATURE"; then
        echo "❌ Embedded ACP helper is missing a secure timestamp"
        exit 1
    fi
    echo "✅ Embedded ACP helper has a hardened runtime and secure timestamp"
fi
