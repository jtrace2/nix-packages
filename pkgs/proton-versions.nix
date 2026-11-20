{ pkgs, lib }:
let
  mkProton = import ./proton-builder.nix { inherit pkgs lib; };

  mkSet = { file, dirName, build }:
    let
      entries = builtins.fromJSON (builtins.readFile file);
    in
    {
      newest = build (builtins.head entries);
      all = lib.listToAttrs (map (e: lib.nameValuePair (dirName e) (build e)) entries);
    };
in
{
  proton-ge = mkSet {
    file = ./versions/proton-ge.json;
    dirName = e: e.tag;
    build = e: mkProton {
      pname = "proton-ge";
      version = e.tag;
      url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${e.tag}/${e.tag}-x86_64.tar.gz";
      inherit (e) hash;
    };
  };

  proton-cachyos = mkSet {
    file = ./versions/proton-cachyos.json;
    dirName = e: "proton-${e.tag}";
    build = e: mkProton {
      pname = "proton-cachyos";
      version = "${e.tag}-x86_64";
      url = "https://github.com/CachyOS/proton-cachyos/releases/download/${e.tag}/proton-${e.tag}-x86_64.tar.xz";
      inherit (e) hash;
    };
  };

  proton-em = mkSet {
    file = ./versions/proton-em.json;
    dirName = e: e.tag;
    build = e: mkProton {
      pname = "proton-em";
      version = e.tag;
      url = "https://github.com/Etaash-mathamsetty/Proton/releases/download/${e.tag}/proton-${e.tag}.tar.xz";
      inherit (e) hash;
    };
  };

  proton-kron4ek = mkSet {
    file = ./versions/proton-kron4ek.json;
    dirName = e: "wine-kron4ek-${e.tag}-wow64";
    # Wine braucht zusaetzlich «files -> .». Der Archiv-Baum bleibt unveraendert
    # (Fixed-Output), dieser Mini-Wrapper setzt nur Symlinks (kein Kopieren,
    # Millisekunden) und haengt deshalb nicht von einem grossen Neubau ab.
    build = e:
      let
        tree = mkProton {
          pname = "wine-kron4ek";
          version = "${e.tag}-amd64-wow64";
          url = "https://github.com/Kron4ek/Wine-Builds/releases/download/${e.tag}/wine-${e.tag}-amd64-wow64.tar.xz";
          inherit (e) hash;
        };
      in
      pkgs.runCommandLocal "wine-kron4ek-${e.tag}-amd64-wow64" { } ''
        mkdir -p $out
        for f in ${tree}/*; do
          ln -s "$f" "$out/$(basename "$f")"
        done
        ln -s . $out/files
      '';
  };
}
