{ pkgs, lib }:
{ pname, version, url, hash, nativeBuildInputs ? [ ] }:
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version nativeBuildInputs;
  src = pkgs.fetchurl { inherit url hash; };
  dontBuild = true;
  installPhase = "mkdir -p $out && cp -r . $out";
}
