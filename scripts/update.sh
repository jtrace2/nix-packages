#!/usr/bin/env bash
# Aktualisiert ein Paket auf die neueste stabile Upstream-Version.
#
# Aufruf:
#   scripts/update.sh <paket>            faugus-launcher | proton-ge |
#                                        proton-cachyos | proton-em | proton-kron4ek
#   scripts/update.sh <paket> --check    nur prüfen, nichts ändern
#
# Setzt in der Paketdatei Version (oder Tag) und Hash, je in einer eigenen
# Zeile. Es wird nichts committet. Die GitHub-Action baut danach das Paket und
# öffnet einen Pull-Request, der von Hand geprüft und gemergt wird.
#
# Ist INFO_FILE gesetzt, schreibt das Skript dort einen kurzen Text mit
# Versionssprung und Release-Notes-Link hin (wird als Pull-Request-Text benutzt).
#
# Voraussetzungen: curl, jq, nix. «releases/latest» liefert nur stabile
# Releases, keine Vorabversionen. Passt ein Tag nicht zum erwarteten Muster
# (zum Beispiel eine neue Hauptversion mit anderem Namensschema), bricht das
# Skript ab, statt eine unbekannte Datei zu holen.
set -euo pipefail
cd "$(dirname "$0")/.."

pkg="${1:?Paketname angeben, siehe Kopf der Datei}"
check_only="${2:-}"

api() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$1"
  else
    curl -fsSL "$1"
  fi
}

# Pro Paket: Datei, Repo, Feld in der Datei, erlaubtes Tag-Muster, Download-Link.
tag_pattern='.*'
case "$pkg" in
  faugus-launcher)
    file="pkgs/faugus-launcher.nix"; repo="Faugus/faugus-launcher"; field="version"
    ;;
  proton-ge)
    file="pkgs/proton-ge.nix"; repo="GloriousEggroll/proton-ge-custom"; field="version"
    tag_pattern='^GE-Proton[0-9]+-[0-9]+$'
    asset() { echo "https://github.com/$repo/releases/download/$1/$1-x86_64.tar.gz"; }
    ;;
  proton-cachyos)
    file="pkgs/proton-cachyos.nix"; repo="CachyOS/proton-cachyos"; field="tag"
    tag_pattern='^cachyos-[0-9.]+-[0-9]{8}-slr$'
    asset() { echo "https://github.com/$repo/releases/download/$1/proton-$1-x86_64.tar.xz"; }
    ;;
  proton-em)
    file="pkgs/proton-em.nix"; repo="Etaash-mathamsetty/Proton"; field="tag"
    tag_pattern='^EM-[0-9.]+-[0-9]+(-HDR)?$'
    asset() { echo "https://github.com/$repo/releases/download/$1/proton-$1.tar.xz"; }
    ;;
  proton-kron4ek)
    file="pkgs/proton-kron4ek.nix"; repo="Kron4ek/Wine-Builds"; field="tag"
    tag_pattern='^[0-9]+\.[0-9]+$'
    asset() { echo "https://github.com/$repo/releases/download/$1/wine-$1-amd64-wow64.tar.xz"; }
    ;;
  *)
    echo "Unbekanntes Paket: $pkg" >&2
    exit 1
    ;;
esac

current=$(sed -n "s/^ *$field = \"\(.*\)\";/\1/p" "$file" | head -n1)
latest=$(api "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)

if [ -z "$current" ] || [ -z "$latest" ] || [ "$latest" = "null" ]; then
  echo "Fehler: Version konnte nicht gelesen werden (aktuell: '$current', neu: '$latest')." >&2
  exit 1
fi

echo "$pkg: aktuell $current, neueste stabile $latest"

if [ "$current" = "$latest" ]; then
  echo "Nichts zu tun."
  exit 0
fi

if ! echo "$latest" | grep -Eq "$tag_pattern"; then
  echo "Fehler: Tag '$latest' passt nicht zum erwarteten Muster '$tag_pattern'." >&2
  echo "Das Namensschema hat sich vermutlich geändert, bitte von Hand prüfen." >&2
  exit 1
fi

if [ "$check_only" = "--check" ]; then
  exit 0
fi

if [ "$pkg" = "faugus-launcher" ]; then
  hash=$(nix flake prefetch --json "github:$repo/$latest" | jq -r .hash)
else
  hash=$(nix store prefetch-file --json "$(asset "$latest")" | jq -r .hash)
fi

case "$hash" in
  sha256-*) ;;
  *) echo "Fehler: ungültiger Hash '$hash'." >&2; exit 1 ;;
esac

sed -i "s|^\( *\)$field = \".*\";|\1$field = \"$latest\";|" "$file"
sed -i "s|^\( *\)hash = \".*\";|\1hash = \"$hash\";|" "$file"

echo "Aktualisiert: $current -> $latest ($hash)"

if [ -n "${INFO_FILE:-}" ]; then
  {
    echo "Automatisches Update von **$pkg**: \`$current\` auf \`$latest\`."
    echo
    echo "Release-Notes: https://github.com/$repo/releases/tag/$latest"
    echo
    echo "Vor dem Mergen die Release-Notes lesen. Der Bau ist in der CI geprüft."
  } > "$INFO_FILE"
fi
