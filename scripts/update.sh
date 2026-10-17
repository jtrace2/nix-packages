#!/usr/bin/env bash
# Aktualisiert ein Paket auf die neueste stabile Upstream-Version.
#
# Aufruf:
#   scripts/update.sh <paket>            faugus-launcher | proton-ge |
#                                        proton-cachyos | proton-em | proton-kron4ek
#   scripts/update.sh <paket> --check    nur prüfen, nichts ändern
#
# Faugus: Version und Hash werden in pkgs/faugus-launcher.nix ersetzt (nur die
# neueste Version wird gehalten).
#
# Proton-Arten: pkgs/versions/<paket>.json enthält die behaltenen Versionen,
# neueste zuerst. Das Skript ergänzt eine neue Version vorne und entfernt alte
# Einträge nach dieser Regel (auch ohne neue Version):
#   - behalten: alles, was in den letzten KEEP_DAYS Tagen erschienen ist,
#   - aber mindestens MIN_KEEP Versionen (damit ein Zurück möglich bleibt),
#   - und höchstens MAX_KEEP Versionen (damit der Speicher begrenzt bleibt).
# Häufig aktualisierte Proton-Arten behalten so automatisch mehr Versionen,
# selten aktualisierte weniger.
#
# Es wird nichts committet. Die GitHub-Action baut danach das Paket und öffnet
# einen Pull-Request, der von Hand geprüft und gemergt wird.
#
# Ist INFO_FILE gesetzt, schreibt das Skript dort einen kurzen Text mit
# Änderungen und Release-Notes-Link hin (wird als Pull-Request-Text benutzt).
#
# Voraussetzungen: curl, jq, nix. «releases/latest» liefert nur stabile
# Releases, keine Vorabversionen. Passt ein Tag nicht zum erwarteten Muster
# (zum Beispiel eine neue Hauptversion mit anderem Namensschema), bricht das
# Skript ab, statt eine unbekannte Datei zu holen.
set -euo pipefail
cd "$(dirname "$0")/.."

# jq und curl fehlen auf manchen Systemen: dann das Skript einmal mit beiden
# Werkzeugen aus Nix neu starten.
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

# ---------------------------------------------------------------- Faugus
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

# ---------------------------------------------------------------- Proton
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
