{ pkgs, lib }:
let
  proton = import ./proton-versions.nix { inherit pkgs lib; };
in
{
  # Faugus als eigenes Paket, unabhängig vom nixpkgs-Verzug.
  faugus-launcher = pkgs.callPackage ./faugus-launcher.nix { };

  # Jeweils die neueste Version. Alle behaltenen Versionen liefert
  # proton-versions.nix (siehe flake.nix, lib.protonVersions).
  proton-ge = proton.proton-ge.newest;
  proton-cachyos = proton.proton-cachyos.newest;
  proton-em = proton.proton-em.newest;
  proton-kron4ek = proton.proton-kron4ek.newest;
}
