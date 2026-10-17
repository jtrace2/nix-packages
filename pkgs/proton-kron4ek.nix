{ mkProton }:
# Kron4ek Wine-Builds: reines, stabiles Wine (kein Staging, keine TKG-Patches)
# als dritter, unabhängiger Zweig neben GE und CachyOS. Gewählt ist die
# wow64-Variante (ein einzelnes «wine»-Binary für 32 und 64 Bit, wie bei
# GE-Proton). Tag und Hash stehen je in einer eigenen Zeile, damit
# scripts/update.sh sie ersetzen kann.
#
# Die Archivstruktur ist anders als bei Proton (bin/wine statt files/bin/wine).
# Deshalb ein zusätzlicher files-Symlink, damit Code, der überall
# «${protonPath}/files/bin/wine» erwartet, ohne Sonderfall auskommt.
let
  tag = "11.16";
  hash = "sha256-Y9XkWkhDkwynUSzBwL005tQJPcOS2WoXUlRd6iif6vQ=";
in
(mkProton {
  pname = "wine-kron4ek";
  version = "${tag}-amd64-wow64";
  url = "https://github.com/Kron4ek/Wine-Builds/releases/download/${tag}/wine-${tag}-amd64-wow64.tar.xz";
  inherit hash;
}).overrideAttrs (_old: {
  installPhase = ''
    mkdir -p $out
    cp -r . $out
    ln -s . $out/files
  '';
})
