#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  exec nix shell nixpkgs#jq nixpkgs#curl --command "$0" "$@"
fi

KEEP_DAYS="${KEEP_DAYS:-60}"
MIN_KEEP="${MIN_KEEP:-2}"
MAX_KEEP="${MAX_KEEP:-6}"

pkg="${1:?usage: scripts/update.sh <package> [--check]}"
check_only="${2:-}"

api() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$1"
  else
    curl -fsSL "$1"
  fi
}

write_info() {
  [ -n "${INFO_FILE:-}" ] || return 0
  {
    echo "Automatic update of **$pkg**."
    echo
    [ -n "$1" ] && echo "- Added: \`$1\`"
    [ -n "$2" ] && echo "- Removed (older than $KEEP_DAYS days, above the minimum): \`$2\`"
    echo
    echo "Release notes: https://github.com/$repo/releases/tag/$latest"
    echo
    echo "Read the release notes before merging. The build was verified in CI."
  } > "$INFO_FILE"
}

tag_pattern='.*'
case "$pkg" in
  faugus-launcher)
    mode="sed"; file="pkgs/faugus-launcher.nix"; repo="Faugus/faugus-launcher"
    tag_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'
    ;;
  proton-ge)
    mode="json"; file="pkgs/versions/proton-ge.json"; repo="GloriousEggroll/proton-ge-custom"
    tag_pattern='^GE-Proton[0-9]+-[0-9]+$'
    asset() { echo "https://github.com/$repo/releases/download/$1/$1-x86_64.tar.gz"; }
    ;;
  proton-cachyos)
    mode="json"; file="pkgs/versions/proton-cachyos.json"; repo="CachyOS/proton-cachyos"
    tag_pattern='^cachyos-[0-9.]+-[0-9]{8}-slr$'
    asset() { echo "https://github.com/$repo/releases/download/$1/proton-$1-x86_64.tar.xz"; }
    ;;
  proton-em)
    mode="json"; file="pkgs/versions/proton-em.json"; repo="Etaash-mathamsetty/Proton"
    tag_pattern='^EM-[0-9.]+-[0-9]+(-HDR)?$'
    asset() { echo "https://github.com/$repo/releases/download/$1/proton-$1.tar.xz"; }
    ;;
  proton-kron4ek)
    mode="json"; file="pkgs/versions/proton-kron4ek.json"; repo="Kron4ek/Wine-Builds"
    tag_pattern='^[0-9]+\.[0-9]+$'
    asset() { echo "https://github.com/$repo/releases/download/$1/wine-$1-amd64-wow64.tar.xz"; }
    ;;
  *)
    echo "Unknown package: $pkg" >&2
    exit 1
    ;;
esac

releases=$(api "https://api.github.com/repos/$repo/releases?per_page=30")
release=$(jq -c --arg p "$tag_pattern" '
  [.[] | select((.draft | not) and (.prerelease | not) and (.tag_name | test($p)))]
  | .[0] // empty' <<<"$releases")

if [ -z "$release" ]; then
  echo "Error: no stable release matching the tag pattern '$tag_pattern' found." >&2
  echo "The naming scheme has probably changed, please check by hand." >&2
  exit 1
fi

latest=$(jq -r .tag_name <<<"$release")
published=$(jq -r '.published_at[:10]' <<<"$release")

newest_any=$(jq -r '.[0].tag_name' <<<"$releases")
if [ "$newest_any" != "$latest" ]; then
  echo "Note: newest release '$newest_any' is not a stable release and is skipped."
fi

if [ "$mode" = "sed" ]; then
  current=$(sed -n 's/^ *version = "\(.*\)";/\1/p' "$file" | head -n1)
  echo "$pkg: current $current, newest stable $latest"
  [ "$current" != "$latest" ] || { echo "Nothing to do."; exit 0; }
  [ "$check_only" != "--check" ] || exit 0

  hash=$(nix flake prefetch --json "github:$repo/$latest" | jq -r .hash)
  case "$hash" in sha256-*) ;; *) echo "Error: invalid hash '$hash'." >&2; exit 1 ;; esac

  sed -i "s|^\( *\)version = \".*\";|\1version = \"$latest\";|" "$file"
  sed -i "s|^\( *\)hash = \".*\";|\1hash = \"$hash\";|" "$file"
  echo "Updated: $current -> $latest ($hash)"
  write_info "$latest" ""
  exit 0
fi

data=$(cat "$file")
is_new=$(jq -r --arg t "$latest" 'map(select(.tag == $t)) | length' <<<"$data")
cutoff=$(date -d "-$KEEP_DAYS days" +%F)

prune() {
  jq --arg c "$cutoff" --argjson min "$MIN_KEEP" --argjson max "$MAX_KEEP" '
    to_entries
    | map(select(.key < $min or .value.date >= $c))
    | map(.value)
    | .[:$max]' <<<"$1"
}

added=""
if [ "$is_new" = "0" ]; then
  added="$latest"
  echo "$pkg: new version $latest ($published)"
  if [ "$check_only" != "--check" ]; then
    hash=$(nix store prefetch-file --json "$(asset "$latest")" | jq -r .hash)
    case "$hash" in sha256-*) ;; *) echo "Error: invalid hash '$hash'." >&2; exit 1 ;; esac
    data=$(jq --arg t "$latest" --arg d "$published" --arg h "$hash" \
      '[{tag: $t, date: $d, hash: $h}] + .' <<<"$data")
  fi
else
  echo "$pkg: $latest is already recorded."
fi

result=$(prune "$data")
removed=$(jq -nr --argjson a "$data" --argjson b "$result" '([$a[].tag] - [$b[].tag]) | join(", ")')
[ -z "$removed" ] || echo "$pkg: will remove: $removed"

if [ "$check_only" = "--check" ]; then
  exit 0
fi

tmp=$(mktemp)
jq --indent 2 . <<<"$result" > "$tmp"
if cmp -s "$tmp" "$file"; then
  rm -f "$tmp"
  echo "Nothing to do."
  exit 0
fi
mv "$tmp" "$file"
echo "Updated: $file"
write_info "$added" "$removed"
