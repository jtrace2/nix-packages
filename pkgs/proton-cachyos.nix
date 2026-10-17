{ mkProton }:
# Proton-CachyOS, allgemeiner x86_64-Build (läuft auf jeder 64-Bit-CPU, die
# Maintainer empfehlen diese Variante). Tag und Hash stehen je in einer eigenen
# Zeile, damit scripts/update.sh sie ersetzen kann.
let
  tag = "cachyos-11.0-20261005-slr";
  hash = "sha256-CWv+c7UG1lZbBOzEUhQZekCRgY8W7ZH1MktNIILQomM=";
in
mkProton {
  pname = "proton-cachyos";
  version = "${tag}-x86_64";
  url = "https://github.com/CachyOS/proton-cachyos/releases/download/${tag}/proton-${tag}-x86_64.tar.xz";
  inherit hash;
}
