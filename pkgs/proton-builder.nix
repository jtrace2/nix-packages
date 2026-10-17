{ pkgs, lib }:
# Generischer «fetch + entpacken»-Builder, ursprünglich für Proton-Builds.
# Wurde zeitweise auch für die DXVK-/VKD3D-Proton-Archive der inzwischen
# entfernten manuellen Spieleverwaltung wiederverwendet. Dieser Teil ist
# 2026-09 mit der ganzen manual-games-Infrastruktur wieder raus.
# nativeBuildInputs ist optional, wird z.B. für .tar.zst-Archive (zstd)
# gebraucht.
{ pname, version, url, hash, nativeBuildInputs ? [ ] }:
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version nativeBuildInputs;
  src = pkgs.fetchurl { inherit url hash; };
  dontBuild = true;
  installPhase = "mkdir -p $out && cp -r . $out";
}
