#!/usr/bin/env bash
# Put this job's installer on the GitHub Release of its version, for the
# website's download links (GitHub's CDN):
#   https://github.com/<repo>/releases/latest/download/opz-mac.dmg
#                                                     /opz-win64.zip
#                                                     /opz-linux-x86_64.tar.xz
# Run after scripts/release.sh, when publishing. Updates of installed copies
# (.mar, update.xml) stay on the update server.
#
# The release's tag is the bare version ("159.0.1"), not "v159.0.1": v* tags
# start this workflow, and a release is also made by hand sometimes.
# The release is marked Latest only once it holds all three installers, so the
# latest/download links never point at a release that lacks one.
set -euo pipefail
[ -n "${GITHUB_ACTIONS:-}" ] || { echo "ci-github-release: only for GitHub Actions" >&2; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd -P)"
site="$root/dist/release/site"
repo="$GITHUB_REPOSITORY"
ALL=(opz-mac.dmg opz-win64.zip opz-linux-x86_64.tar.xz)

shopt -s nullglob
links=("$site"/latest/*)
[ "${#links[@]}" -eq 1 ] || { echo "ci-github-release: expected one installer in $site/latest" >&2; exit 1; }
stable="$(basename "${links[0]}")"                 # opz-win64.zip
file="$(basename "$(readlink "${links[0]}")")"     # opz-159.0.1-20261123192430.win64.zip
ver="$(echo "$file" | sed -nE 's/^opz-([0-9][0-9a-z.]*)-[0-9]{14}\..*/\1/p')"
[ -n "$ver" ] || { echo "ci-github-release: no version in $file" >&2; exit 1; }
tag="$ver"

notes="Opz Browser $ver, built on Firefox $ver.

| | |
|---|---|
| macOS (Apple Silicon) | \`opz-mac.dmg\`, signed and notarized by Apple |
| Windows 10 / 11 (x64) | \`opz-win64.zip\`, extract it into your user folder (e.g. \`%LOCALAPPDATA%\`). Not code-signed yet: SmartScreen asks the first time, choose **More info → Run anyway**. |
| Linux (x86_64) | \`opz-linux-x86_64.tar.xz\`, extract it anywhere; \`opz/install-desktop.sh\` adds it to the app menu |

Installed copies update themselves."

if ! gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
    # Another platform's job may create it at the same moment.
    gh release create "$tag" -R "$repo" --target "$GITHUB_SHA" --title "Opz $ver" \
        --notes "$notes" --latest=false \
        || gh release view "$tag" -R "$repo" >/dev/null
fi

up="$RUNNER_TEMP/github-release"
rm -rf "$up"; mkdir -p "$up"
cp -L "${links[0]}" "$up/$stable"
gh release upload "$tag" -R "$repo" --clobber "$up/$stable"
rm -rf "$up"
echo "ci-github-release: $stable ($file) on release $tag"

have="$(gh release view "$tag" -R "$repo" --json assets -q '.assets[].name')"
missing=()
for a in "${ALL[@]}"; do grep -qxF "$a" <<<"$have" || missing+=("$a"); done
if [ "${#missing[@]}" -eq 0 ]; then
    gh release edit "$tag" -R "$repo" --latest
    echo "ci-github-release: $tag has all installers; marked Latest"
else
    echo "ci-github-release: $tag still lacks ${missing[*]}; not marked Latest yet"
fi
