{ pkgs, lib }:
# Alle behaltenen Versionen je Proton-Art. Die Listen stehen in versions/*.json,
# neueste zuerst. scripts/update.sh ergänzt neue Versionen und entfernt alte
# (Regel dort: letzte 60 Tage, mindestens 2, höchstens 6).
#
# Ergebnis je Art:
#   newest: die neueste Version (ein Paket)
#   all:    alle Versionen, Name = Verzeichnisname für compatibilitytools.d
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
  # GE-Proton. Der Tag ist gleich der Version. Seit GE-Proton11-6 heissen die
  # Release-Dateien «<tag>-x86_64.tar.gz» (es gibt auch eine aarch64-Variante).
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

  # Proton-CachyOS, allgemeiner x86_64-Build (läuft auf jeder 64-Bit-CPU, die
  # Maintainer empfehlen diese Variante).
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

  # Proton-EM (Wayland und HDR).
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

  # Kron4ek Wine-Builds: reines, stabiles Wine (kein Staging, keine TKG-Patches)
  # als dritter, unabhängiger Zweig neben GE und CachyOS, wow64-Variante (ein
  # einzelnes «wine»-Binary für 32 und 64 Bit). Die Archivstruktur ist anders als
  # bei Proton (bin/wine statt files/bin/wine). Deshalb ein zusätzlicher
  # files-Symlink, damit Code, der überall «${protonPath}/files/bin/wine» erwartet,
  # ohne Sonderfall auskommt.
  proton-kron4ek = mkSet {
    file = ./versions/proton-kron4ek.json;
    dirName = e: "wine-kron4ek-${e.tag}-wow64";
    build = e: (mkProton {
      pname = "wine-kron4ek";
      version = "${e.tag}-amd64-wow64";
      url = "https://github.com/Kron4ek/Wine-Builds/releases/download/${e.tag}/wine-${e.tag}-amd64-wow64.tar.xz";
      inherit (e) hash;
    }).overrideAttrs (_old: {
      installPhase = ''
        mkdir -p $out
        cp -r . $out
        ln -s . $out/files
      '';
    });
  };
}
