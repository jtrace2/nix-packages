# nix-packages

Eigene Nix-Pakete, die schneller aktuell sind als nixpkgs. Eine tägliche GitHub-Action prüft auf neue Versionen, baut sie und öffnet einen Pull-Request.

## Pakete

| Paket | Quelle |
| --- | --- |
| `faugus-launcher` | [Faugus/faugus-launcher](https://github.com/Faugus/faugus-launcher) |
| `proton-ge` | [GloriousEggroll/proton-ge-custom](https://github.com/GloriousEggroll/proton-ge-custom) |
| `proton-cachyos` | [CachyOS/proton-cachyos](https://github.com/CachyOS/proton-cachyos) (allgemeiner x86_64-Build) |
| `proton-em` | [Etaash-mathamsetty/Proton](https://github.com/Etaash-mathamsetty/Proton) |
| `proton-kron4ek` | [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds) (wow64, ohne Staging) |

Faugus braucht `lsfg-vk`, das eine unfreie Lizenz hat. Das Flake erlaubt nur dieses eine Paket.

## Benutzen

Als Flake-Input:

```nix
inputs.nix-packages.url = "github:jtrace2/nix-packages";
```

Als Overlay (Pakete mit den `pkgs` des eigenen Systems bauen):

```nix
nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
```

Oder die Pakete direkt aufrufen, mit der gleichen Schnittstelle wie ein `custom-packages.nix`:

```nix
inputs.nix-packages.lib.customPackages { inherit pkgs lib; }
```

Lokal bauen:

```
nix build .#faugus-launcher
```

## Aufbau

- `flake.nix`: Ausgaben (`packages`, `overlays.default`, `lib.customPackages`).
- `pkgs/`: je eine Datei pro Paket, `default.nix` fasst sie zusammen.
- `scripts/update.sh`: holt die neueste stabile Version und setzt Version oder Tag und Hash.
- `.github/workflows/update.yml`: täglicher Lauf, pro Paket ein Pull-Request.

## Ablauf bei einer neuen Version

1. Die Action erkennt eine neue stabile Version und trägt sie ein.
2. Das Paket wird gebaut. Nur bei Erfolg entsteht ein Pull-Request.
3. Release-Notes lesen, Pull-Request von Hand mergen. Es gibt keinen Automerge.
4. Im eigenen System das Flake aktualisieren (`nix flake update nix-packages`). Erst dann kommt die neue Version auf das System.

Einzeln prüfen, ohne etwas zu ändern:

```
scripts/update.sh faugus-launcher --check
```

## Hinweise

- Das Repo enthält keine Zugangsdaten und keine privaten Daten.
- Weicht ein Tag vom erwarteten Namensmuster ab, bricht das Skript ab, statt eine unbekannte Datei zu holen.
- Das Repo lässt sich jederzeit zu einem anderen Anbieter verschieben, die Pakete sind reine Nix-Dateien.

## Lizenz

Die Paketdefinitionen in diesem Repo stehen unter der MIT-Lizenz (siehe `LICENSE`). Die gepackte Software behält ihre eigene Lizenz.
