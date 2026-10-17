{
  description = "Eigene Nix-Pakete (Faugus, Proton-Builds), automatisch aktuell gehalten";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "lsfg-vk" ];
      };
    in
    {
      lib.customPackages = import ./pkgs;

      lib.protonVersions = import ./pkgs/proton-versions.nix;

      packages.${system} = import ./pkgs { inherit pkgs lib; };

      overlays.default = final: _prev: import ./pkgs { pkgs = final; inherit (final) lib; };
    };
}
