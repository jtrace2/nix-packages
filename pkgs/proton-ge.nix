{ mkProton }:
# GE-Proton. Version und Hash stehen je in einer eigenen Zeile, damit
# scripts/update.sh sie ersetzen kann. Der Tag ist gleich der Version.
# ACHTUNG: seit GE-Proton11-6 heissen die Release-Assets
# «<version>-x86_64.tar.gz» (es gibt auch eine -aarch64-Variante).
mkProton rec {
  pname = "proton-ge";
  version = "GE-Proton11-7";
  url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${version}/${version}-x86_64.tar.gz";
  hash = "sha256-xUSLdqIwOE4te8a+tcy5e6+34sO2xSfLA6GlRrvLAKA=";
}
