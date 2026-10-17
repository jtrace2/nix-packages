{
  description = "Eigene Nix-Pakete (Faugus, Proton-Builds), automatisch aktuell gehalten";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      # Faugus braucht lsfg-vk (unfree). Nur dieses eine Paket wird erlaubt.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "lsfg-vk" ];
      };
    in
    {
      # Gleiche Schnittstelle wie bisher packages/custom-packages.nix im
      # Personal-Repo ({ pkgs, lib }: { ... }), damit der Umstieg klein bleibt.
      lib.customPackages = import ./pkgs;

      # Alle behaltenen Proton-Versionen: { proton-ge = { newest; all; }; ... },
      # «all» ist ein Satz aus Verzeichnisname und Paket.
      lib.protonVersions = import ./pkgs/proton-versions.nix;

      # Für die CI und zum Ausprobieren: nix build .#faugus-launcher
      packages.${system} = import ./pkgs { inherit pkgs lib; };

      # Für das eigene System: die Pakete mit den pkgs des Systems bauen.
      overlays.default = final: _prev: import ./pkgs { pkgs = final; inherit (final) lib; };
    };
}
