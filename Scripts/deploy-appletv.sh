#!/bin/zsh
#
# Deploy "Swiftfin Local" to the Apple TV over the network.
#
# Free-Apple-ID signing: the provisioning profile is only valid 7 days from
# creation, so this script must be re-run at least weekly. It deletes the
# cached profile first so every run embeds a FRESH 7-day profile (otherwise
# Xcode reuses the cached one and the app can die early).
#
# Requirements (one-time):
#   - Xcode signed in to the Apple ID (Xcode > Settings > Accounts)
#   - Apple TV paired (Xcode > Window > Devices and Simulators)
#
# Usage: Scripts/deploy-appletv.sh
#
# Output contract: progress goes to stderr; stdout is a single final summary
# line, so an Apple Shortcut can pipe it straight into a "Show Notification"
# action ("Résultat du script shell" magic variable).
#
set -euo pipefail

DEVICE_ID="BB8195CC-B645-53CE-B225-6FCD3AA2EFE6" # Sonyapptv — Apple TV 4K
BUNDLE_ID="org.jellyfin.swiftfin.local.cnaimi"
SCHEME="Swiftfin tvOS"
CONFIG="Release"
PROJECT_DIR="${0:a:h:h}"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/SwiftfinDeploy"
LOG="/tmp/swiftfin-deploy-$(date +%Y%m%d-%H%M%S).log"

notify() { # notify <title> <message> — for terminal/launchd runs; no-op-safe
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"Glass\"" 2>/dev/null || true
}
on_error() {
    notify "Swiftfin deploy FAILED" "See $LOG"
    echo "❌ Swiftfin deploy FAILED — see $LOG"
}
trap on_error ERR

echo "==> [1/4] Clearing cached provisioning profiles for $BUNDLE_ID" >&2
for dir in \
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
    "$HOME/Library/MobileDevice/Provisioning Profiles"
do
    [[ -d $dir ]] || continue
    for f in "$dir"/*.mobileprovision(N); do
        if security cms -D -i "$f" 2>/dev/null | grep -q "$BUNDLE_ID"; then
            rm "$f"
            echo "    removed $(basename "$f")" >&2
        fi
    done
done

echo "==> [2/4] Building $SCHEME ($CONFIG) — log: $LOG" >&2
xcodebuild \
    -project "$PROJECT_DIR/Swiftfin.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "generic/platform=tvOS" \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    build >"$LOG" 2>&1 || { tail -30 "$LOG" >&2; false; }

APP="$DERIVED/Build/Products/$CONFIG-appletvos/$SCHEME.app"

echo "==> [3/4] Installing to Apple TV ($DEVICE_ID)" >&2
xcrun devicectl device install app --device "$DEVICE_ID" "$APP" >&2

EXPIRY="$(date -v+7d '+%A %d %B %H:%M')"
echo "==> [4/4] Done. Profile valid until $EXPIRY." >&2
notify "Swiftfin deployed to Apple TV ✅" "Valid until $EXPIRY"

# The ONLY stdout line — becomes the Shortcut's notification body.
echo "✅ Déployé sur l'Apple TV — valide jusqu'au $EXPIRY"
