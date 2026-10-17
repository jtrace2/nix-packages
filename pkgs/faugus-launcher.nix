{
  coreutils,
  fetchFromGitHub,
  gamemode,
  gawk,
  gnugrep,
  gobject-introspection,
  gst_all_1,
  icoextract,
  lib,
  libadwaita,
  libgudev,
  libmanette,
  lsfg-vk,
  meson,
  ninja,
  nix-update-script,
  python3Packages,
  umu-launcher,
  wrapGAppsHook4,
  xdg-utils,
}:

# Eigenes Paket statt overrideAttrs auf nixpkgs (2026-10): nixpkgs hing bei 2.3.0,
# Upstream war weiter. Vorlage: pkgs/by-name/fa/faugus-launcher/package.nix.
# Neue Version: scripts/update.sh faugus-launcher (läuft auch täglich in der
# GitHub-Action und öffnet einen Pull-Request). Version und Hash stehen je in
# einer eigenen Zeile, damit das Skript sie ersetzen kann. Bricht der Build
# wegen einer neuen Abhängigkeit, wird sie unten in der jeweiligen Liste
# ergänzt.
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "faugus-launcher";
  version = "2.5.0";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "Faugus";
    repo = "faugus-launcher";
    tag = finalAttrs.version;
    hash = "sha256-rRDgLBzBJGk5o/2y6GRHHuLTMwZwXdb1O5YKTvu99Xc=";
  };

  nativeBuildInputs = [
    gobject-introspection
    meson
    ninja
    wrapGAppsHook4
  ];

  buildInputs = [
    libadwaita
    libmanette
    libgudev
  ]
  ++ (with gst_all_1; [
    gst-plugins-base
    gst-plugins-good
    gstreamer
  ]);

  dependencies = with python3Packages; [
    dbus-python
    pillow
    psutil
    pygobject3
    requests
    vdf
  ];

  postPatch = ''
    substituteInPlace faugus-launcher \
      --replace-fail "/usr/bin/python3" "${python3Packages.python.interpreter}"

    substituteInPlace faugus/path_manager.py \
      --replace-fail "PathManager.user_data('faugus-launcher/umu-run')" "'${lib.getExe umu-launcher}'" \
      --replace-fail "/usr/lib/extensions/vulkan/lsfgvk/lib/liblsfg-vk.so" "${lsfg-vk}/lib/liblsfg-vk.so" \
      --replace-fail "/usr/lib/liblsfg-vk.so" "${lsfg-vk}/lib/liblsfg-vk.so"
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set PYTHONPATH "$out/${python3Packages.python.sitePackages}:$PYTHONPATH"
      --set LD_PRELOAD "libgamemode.so:$LD_PRELOAD"
      --set LD_LIBRARY_PATH "${lib.getLib gamemode}/lib:$LD_LIBRARY_PATH"
      --suffix PATH : "${
        lib.makeBinPath [
          coreutils
          gawk
          gnugrep
          icoextract
          umu-launcher
          xdg-utils
        ]
      }"
    )
  '';

  # Keine Tests vorhanden
  doCheck = false;

  pythonImportsCheck = [ "faugus" ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Simple and lightweight app for running Windows games using UMU-Launcher";
    homepage = "https://github.com/Faugus/faugus-launcher";
    changelog = "https://github.com/Faugus/faugus-launcher/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    mainProgram = "faugus-launcher";
    platforms = lib.platforms.linux;
  };
})
