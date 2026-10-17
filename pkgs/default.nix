{ pkgs, lib }:
let
  mkProton = import ./proton-builder.nix { inherit pkgs lib; };
in
{
  # Faugus als eigenes Paket, unabhängig vom nixpkgs-Verzug.
  faugus-launcher = pkgs.callPackage ./faugus-launcher.nix { };

  # Alle fünf werden automatisch aktualisiert (scripts/update.sh).
  proton-ge = import ./proton-ge.nix { inherit mkProton; };
  proton-cachyos = import ./proton-cachyos.nix { inherit mkProton; };
  proton-em = import ./proton-em.nix { inherit mkProton; };
  proton-kron4ek = import ./proton-kron4ek.nix { inherit mkProton; };
}
