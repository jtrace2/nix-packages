{ mkProton }:
# Proton-EM (Wayland und HDR). Tag und Hash stehen je in einer eigenen Zeile,
# damit scripts/update.sh sie ersetzen kann.
let
  tag = "EM-10.0-37-HDR";
  hash = "sha256-W/2BzrQjs2W1R4A9Q0/VFX3v6uURYLv2ZXJlvENAWG0=";
in
mkProton {
  pname = "proton-em";
  version = tag;
  url = "https://github.com/Etaash-mathamsetty/Proton/releases/download/${tag}/proton-${tag}.tar.xz";
  inherit hash;
}
