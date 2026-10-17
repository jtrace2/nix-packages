{ pkgs, lib }:
let
  proton = import ./proton-versions.nix { inherit pkgs lib; };
in
{
  faugus-launcher = pkgs.callPackage ./faugus-launcher.nix { };

  proton-ge = proton.proton-ge.newest;
  proton-cachyos = proton.proton-cachyos.newest;
  proton-em = proton.proton-em.newest;
  proton-kron4ek = proton.proton-kron4ek.newest;
}
