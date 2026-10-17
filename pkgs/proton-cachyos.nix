{ mkProton }:
# Proton-CachyOS (x86_64_v3-Variante). Tag und Hash stehen je in einer eigenen
# Zeile, damit scripts/update.sh sie ersetzen kann.
let
  tag = "cachyos-11.0-20260703-slr";
  hash = "sha256-A+zUK9fUdOm6RDzoly2WeKH6Osvykg12HzU5eUbs4oQ=";
in
mkProton {
  pname = "proton-cachyos";
  version = "${tag}-x86_64_v3";
  url = "https://github.com/CachyOS/proton-cachyos/releases/download/${tag}/proton-${tag}-x86_64_v3.tar.xz";
  inherit hash;
}
