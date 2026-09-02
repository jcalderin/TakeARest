#!/usr/bin/env bash
# Build, package and publish a Respite release to GitHub Releases.
#
# Usage: scripts/release.sh <version> [--dry-run] [--draft] [--prerelease]
#   <version>     semver without the leading "v", e.g. 1.3.0
#   --dry-run     build + package into dist/ only; no commit, tag, push or release
#   --draft       create the GitHub release as a draft
#   --prerelease  mark the GitHub release as a prerelease
#
# What it does:
#   1. preflight: clean tree on main, up to date with origin, tag free, gh can push
#   2. set CFBundleShortVersionString=<version>, CFBundleVersion=<commit count>
#   3. `make build` (Release, ad-hoc signed), verify version + universal binary
#   4. package dist/Respite-<version>.{zip,dmg} + SHA256SUMS.txt
#   5. commit the version bump, tag v<version>, push, `gh release create`
set -euo pipefail

APP="Respite"
PLIST="Respite/Info.plist"
PRODUCT="build/Build/Products/Release/$APP.app"
DIST="dist"
DEFAULT_BRANCH="main"
PLISTBUDDY="/usr/libexec/PlistBuddy"

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# --- args ------------------------------------------------------------------
VERSION=""; DRY_RUN=0; GH_FLAGS=()
for arg in "$@"; do
  case "$arg" in
    --dry-run)            DRY_RUN=1 ;;
    --draft|--prerelease) GH_FLAGS+=("$arg") ;;
    -h|--help)            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)                   die "unknown flag: $arg" ;;
    *)                    VERSION="$arg" ;;
  esac
done
[[ -n "$VERSION" ]] || die "usage: $0 <version> [--dry-run] [--draft] [--prerelease]"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.]+)?$ ]] || die "version must be semver like 1.3.0 (got '$VERSION')"
TAG="v$VERSION"

# --- preflight -------------------------------------------------------------
step "Preflight $TAG"
cd "$(git rev-parse --show-toplevel)"
for tool in gh xcodebuild hdiutil ditto lipo codesign; do
  command -v "$tool" >/dev/null || die "missing tool: $tool"
done
[[ -x "$PLISTBUDDY" ]] || die "missing $PLISTBUDDY"

# owner/repo from the origin URL; works for ssh host aliases and https
REPO="$(git remote get-url origin | sed -E 's#\.git$##; s#^.*[:/]([^/]+/[^/]+)$#\1#')"
[[ "$REPO" == */* ]] || die "cannot parse owner/repo from origin URL"
echo "repo:    $REPO"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "$DEFAULT_BRANCH" ]]; then
  (( DRY_RUN )) && warn "not on $DEFAULT_BRANCH (on $BRANCH)" || die "must release from $DEFAULT_BRANCH (on $BRANCH)"
fi
if [[ -n "$(git status --porcelain)" ]]; then
  (( DRY_RUN )) && warn "working tree is dirty" || die "working tree must be clean (commit or stash first)"
fi

git fetch -q origin "$DEFAULT_BRANCH" --tags
if ! git merge-base --is-ancestor "origin/$DEFAULT_BRANCH" HEAD; then
  (( DRY_RUN )) && warn "HEAD is behind origin/$DEFAULT_BRANCH" || die "HEAD is behind origin/$DEFAULT_BRANCH; pull first"
fi
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists locally"
git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 && die "tag $TAG already exists on origin"

if ! gh auth status >/dev/null 2>&1; then
  die "gh is not authenticated; run: gh auth login"
fi
if [[ "$(gh api "repos/$REPO" --jq '.permissions.push' 2>/dev/null)" != "true" ]]; then
  MSG="gh account '$(gh api user --jq .login 2>/dev/null)' cannot push to $REPO. Run: gh auth login (as ${REPO%%/*}) or: gh auth switch --user ${REPO%%/*}"
  (( DRY_RUN )) && warn "$MSG" || die "$MSG"
fi

PREV_TAG="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "version: $VERSION (build $BUILD_NUMBER), previous tag: ${PREV_TAG:-none}"

# --- release notes (before the version-bump commit exists) -----------------
TMP="$(mktemp -d)"
COMMITTED=0
cleanup() {
  # restore Info.plist on dry-run or on failure before the bump was committed
  if [[ -f "$TMP/Info.plist.orig" && $COMMITTED -eq 0 ]]; then cp "$TMP/Info.plist.orig" "$PLIST"; fi
  rm -rf "$TMP"
}
trap cleanup EXIT

NOTES="$TMP/notes.md"
{
  if [[ -n "$PREV_TAG" ]]; then
    echo "## Changes since $PREV_TAG"
    git log --no-merges --pretty='- %s' "$PREV_TAG..HEAD"
  else
    echo "## Changes"
    git log --no-merges --pretty='- %s'
  fi
  cat <<NOTES

## Install
1. Download **$APP-$VERSION.dmg**, open it and drag **$APP** into **Applications**.
2. First launch: this build is not notarized, so macOS will block it once. Double-click $APP, click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   Terminal alternative: \`xattr -dr com.apple.quarantine /Applications/$APP.app\`
3. Requires macOS 15 or later. $APP lives in the menu bar and has no Dock icon.

Checksums: \`shasum -a 256 -c SHA256SUMS.txt\`
NOTES
} > "$NOTES"

# --- version bump ----------------------------------------------------------
step "Set version $VERSION (build $BUILD_NUMBER) in $PLIST"
cp "$PLIST" "$TMP/Info.plist.orig"
"$PLISTBUDDY" -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"

# --- build -----------------------------------------------------------------
step "Build Release (ad-hoc signed, universal)"
rm -rf "$PRODUCT" "$DIST"; mkdir -p "$DIST"
if ! make build > "$DIST/build.log" 2>&1; then
  tail -n 40 "$DIST/build.log" >&2
  die "build failed (full log: $DIST/build.log)"
fi

step "Verify $PRODUCT"
BUILT_VERSION="$("$PLISTBUDDY" -c 'Print :CFBundleShortVersionString' "$PRODUCT/Contents/Info.plist")"
[[ "$BUILT_VERSION" == "$VERSION" ]] || die "built app reports version $BUILT_VERSION, expected $VERSION"
ARCHS="$(lipo -archs "$PRODUCT/Contents/MacOS/$APP")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || die "binary is not universal (archs: $ARCHS)"
codesign --verify --deep --strict "$PRODUCT" || die "codesign verification failed"
echo "version $BUILT_VERSION, archs: $ARCHS, signature OK"

# --- package ---------------------------------------------------------------
step "Package into $DIST/"
ZIP="$DIST/$APP-$VERSION.zip"
DMG="$DIST/$APP-$VERSION.dmg"
ditto -c -k --keepParent "$PRODUCT" "$ZIP"
mkdir "$TMP/dmg"
cp -R "$PRODUCT" "$TMP/dmg/"
ln -s /Applications "$TMP/dmg/Applications"
hdiutil create -quiet -volname "$APP $VERSION" -srcfolder "$TMP/dmg" -ov -format UDZO "$DMG"
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" > SHA256SUMS.txt)
ls -lh "$DIST" | tail -n +2

# --- dry run stops here ----------------------------------------------------
if (( DRY_RUN )); then
  step "Dry run: release notes"
  cat "$NOTES"
  step "Dry run complete"
  echo "Would commit '$PLIST', tag $TAG, push to origin and run:"
  echo "  gh release create $TAG -R $REPO --title '$APP $TAG' ${GH_FLAGS[*]:-} $ZIP $DMG $DIST/SHA256SUMS.txt"
  exit 0
fi

# --- commit, tag, push, release --------------------------------------------
step "Commit, tag $TAG and push"
git add "$PLIST"
git commit -q -m "chore(release): $TAG"
COMMITTED=1
git tag -a "$TAG" -m "$APP $TAG"
git push -q origin "$DEFAULT_BRANCH" "$TAG"

step "Create GitHub release $TAG"
gh release create "$TAG" -R "$REPO" \
  --title "$APP $TAG" \
  --notes-file "$NOTES" \
  --verify-tag \
  ${GH_FLAGS[@]+"${GH_FLAGS[@]}"} \
  "$ZIP" "$DMG" "$DIST/SHA256SUMS.txt"

step "Done"
gh release view "$TAG" -R "$REPO" --json url --jq .url
