{ pkgs, lib }:
# Proton/Wine-Archiv als Fixed-Output-Derivation (fetchzip): der Store-Pfad
# haengt NUR von name, url und hash ab, NICHT vom nixpkgs-Stand. Ein
# nixpkgs-Update baut und laedt deshalb nichts neu, nur eine neue Version
# aus den versions/*.json holt etwas.
#
# `hash` ist der Hash des ENTPACKTEN Baums (ein Verzeichnis auf oberster
# Ebene wird abgestreift), nicht des Tarballs. Berechnen mit:
#   nix store prefetch-file --json --unpack <url>
# (scripts/update.sh macht das so).
{ pname, version, url, hash }:
pkgs.fetchzip {
  name = "${pname}-${version}";
  inherit url hash;
}
