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
# Usage: scripts/deploy-appletv.sh
#
set -euo pipefail

DEVICE_ID="BB8195CC-B645-53CE-B225-6FCD3AA2EFE6" # Sonyapptv — Apple TV 4K
BUNDLE_ID="org.jellyfin.swiftfin.local.cnaimi"
SCHEME="Swiftfin tvOS"
CONFIG="Release"
PROJECT_DIR="${0:a:h:h}"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/SwiftfinDeploy"
LOG="/tmp/swiftfin-deploy-$(date +%Y%m%d-%H%M%S).log"

notify() { # notify <title> <message>
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"Glass\"" || true
}
trap 'notify "Swiftfin deploy FAILED" "See $LOG"' ERR

echo "==> [1/4] Clearing cached provisioning profiles for $BUNDLE_ID"
for dir in \
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
    "$HOME/Library/MobileDevice/Provisioning Profiles"
do
    [[ -d $dir ]] || continue
    for f in "$dir"/*.mobileprovision(N); do
        if security cms -D -i "$f" 2>/dev/null | grep -q "$BUNDLE_ID"; then
            rm "$f"
            echo "    removed $(basename "$f")"
        fi
    done
done

echo "==> [2/4] Building $SCHEME ($CONFIG) — log: $LOG"
xcodebuild \
    -project "$PROJECT_DIR/Swiftfin.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "generic/platform=tvOS" \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    build >"$LOG" 2>&1 || { echo "BUILD FAILED — last 30 lines:"; tail -30 "$LOG"; exit 1; }

APP="$DERIVED/Build/Products/$CONFIG-appletvos/$SCHEME.app"

echo "==> [3/4] Installing to Apple TV ($DEVICE_ID)"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

EXPIRY="$(date -v+7d '+%A %d %B %H:%M')"
echo "==> [4/4] Done. Profile valid until $EXPIRY."
notify "Swiftfin deployed to Apple TV ✅" "Valid until $EXPIRY"
