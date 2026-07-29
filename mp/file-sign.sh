  
#!/bin/bash
# fix-itsy-signing.sh — Sign Frameworks → .appex → .app on QA
set -euo pipefail

APP="/Applications/Swifty.app"
APPEX="$APP/Contents/PlugIns/Swifty Extension.appex"
APPEX_BIN="$APPEX/Contents/MacOS/Swifty Extension"
ENT_APP="/tmp/itsy-app-sign.entitlements"
ENT_EXT="/tmp/itsy-extension-sign.entitlements"
SIGN_IDENTITY="-"   # ad-hoc; or: SIGN_IDENTITY="Apple Development: Name (TEAMID)"

[[ -d "$APP" ]] || { echo "Missing $APP"; exit 1; }
[[ -d "$APPEX" ]] || { echo "Missing $APPEX"; exit 1; }

# --- Entitlements ---
cat > "$ENT_EXT" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.code42.incydr</string>
    </array>
</dict>
</plist>
EOF

cat > "$ENT_APP" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.code42.incydr</string>
    </array>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
EOF

plutil -lint "$ENT_EXT" && plutil -lint "$ENT_APP"
xattr -cr "$APP" 2>/dev/null || true
xattr -dr com.apple.quarantine "$APP"

# --- 1) Frameworks (if any) ---
if [[ -d "$APP/Contents/Frameworks" ]]; then
  for f in "$APP/Contents/Frameworks/"*.dylib; do
    [[ -f "$f" ]] || continue
    echo "Signing dylib: $f"
    codesign --force --sign "$SIGN_IDENTITY" "$f"
  done
fi

# --- 2) .appex (extension) — MUST be signed before .app ---
echo "Signing .appex executable..."
[[ -f "$APPEX_BIN" ]] && codesign --force --sign "$SIGN_IDENTITY" "$APPEX_BIN"

echo "Signing .appex bundle (with extension entitlements)..."
codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ENT_EXT" "$APPEX"

# --- 3) .app (container) — sign LAST, NO --deep (so .appex entitlements stay) ---
echo "Signing .app bundle (with app entitlements)..."
codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ENT_APP" "$APP"

# --- Verify both ---
echo ""
echo "=== .appex ==="
codesign --verify --strict "$APPEX" && echo "appex verify: OK"
codesign -d --entitlements :- "$APPEX" 2>&1 | grep -A1 app-sandbox || echo "WARN: no sandbox on appex"

echo ""
echo "=== .app ==="
codesign --verify --deep --strict "$APP" && echo "app verify: OK"
codesign -d --entitlements :- "$APP" 2>&1 | grep -A1 app-sandbox || echo "WARN: no sandbox on app"

echo ""
echo "Authority (.appex):"
codesign -dv "$APPEX" 2>&1 | grep Authority || true
echo "Authority (.app):"
codesign -dv "$APP" 2>&1 | grep Authority || true

echo ""
echo "Safari: Develop → Allow Unsigned Extensions; Settings → Extensions → enable; quit/reopen Safari"
read -r -p "Open app now? [y/N] " ans
[[ "$ans" == [yY]* ]] && open "$APP"
echo "Done."
tccutil reset All com.code42.incydr
echo "Successfully reset All approval status for com.code42.incydr"
