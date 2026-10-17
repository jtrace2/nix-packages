#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  exec nix shell nixpkgs#jq nixpkgs#curl --command "$0" "$@"
fi

KEEP_DAYS="${KEEP_DAYS:-60}"
MIN_KEEP="${MIN_KEEP:-2}"
MAX_KEEP="${MAX_KEEP:-6}"

pkg="${1:?Paketname angeben, siehe Kopf der Datei}"
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
    echo "Automatisches Update von **$pkg**."
    echo
    [ -n "$1" ] && echo "- Neu: \`$1\`"
    [ -n "$2" ] && echo "- Entfernt (älter als $KEEP_DAYS Tage, über dem Minimum): \`$2\`"
    echo
    echo "Release-Notes: https://github.com/$repo/releases/tag/$latest"
    echo
    echo "Vor dem Mergen die Release-Notes lesen. Der Bau ist in der CI geprüft."
  } > "$INFO_FILE"
}

tag_pattern='.*'
case "$pkg" in
  faugus-launcher)
    mode="sed"; file="pkgs/faugus-launcher.nix"; repo="Faugus/faugus-launcher"
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
    echo "Unbekanntes Paket: $pkg" >&2
    exit 1
    ;;
esac

release=$(api "https://api.github.com/repos/$repo/releases/latest")
latest=$(jq -r .tag_name <<<"$release")
published=$(jq -r '.published_at[:10]' <<<"$release")

if [ -z "$latest" ] || [ "$latest" = "null" ]; then
  echo "Fehler: neueste Version konnte nicht gelesen werden." >&2
  exit 1
fi

if ! echo "$latest" | grep -Eq "$tag_pattern"; then
  echo "Fehler: Tag '$latest' passt nicht zum erwarteten Muster '$tag_pattern'." >&2
  echo "Das Namensschema hat sich vermutlich geändert, bitte von Hand prüfen." >&2
  exit 1
fi

if [ "$mode" = "sed" ]; then
  current=$(sed -n 's/^ *version = "\(.*\)";/\1/p' "$file" | head -n1)
  echo "$pkg: aktuell $current, neueste stabile $latest"
  [ "$current" != "$latest" ] || { echo "Nichts zu tun."; exit 0; }
  [ "$check_only" != "--check" ] || exit 0

  hash=$(nix flake prefetch --json "github:$repo/$latest" | jq -r .hash)
  case "$hash" in sha256-*) ;; *) echo "Fehler: ungültiger Hash '$hash'." >&2; exit 1 ;; esac

  sed -i "s|^\( *\)version = \".*\";|\1version = \"$latest\";|" "$file"
  sed -i "s|^\( *\)hash = \".*\";|\1hash = \"$hash\";|" "$file"
  echo "Aktualisiert: $current -> $latest ($hash)"
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
  echo "$pkg: neue Version $latest ($published)"
  if [ "$check_only" != "--check" ]; then
    hash=$(nix store prefetch-file --json "$(asset "$latest")" | jq -r .hash)
    case "$hash" in sha256-*) ;; *) echo "Fehler: ungültiger Hash '$hash'." >&2; exit 1 ;; esac
    data=$(jq --arg t "$latest" --arg d "$published" --arg h "$hash" \
      '[{tag: $t, date: $d, hash: $h}] + .' <<<"$data")
  fi
else
  echo "$pkg: $latest ist schon eingetragen."
fi

result=$(prune "$data")
removed=$(jq -nr --argjson a "$data" --argjson b "$result" '([$a[].tag] - [$b[].tag]) | join(", ")')
[ -z "$removed" ] || echo "$pkg: entfernt wird/werden: $removed"

if [ "$check_only" = "--check" ]; then
  exit 0
fi

tmp=$(mktemp)
jq --indent 2 . <<<"$result" > "$tmp"
if cmp -s "$tmp" "$file"; then
  rm -f "$tmp"
  echo "Nichts zu tun."
  exit 0
fi
mv "$tmp" "$file"
echo "Aktualisiert: $file"
write_info "$added" "$removed"
