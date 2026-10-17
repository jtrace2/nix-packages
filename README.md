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

## Behaltene Versionen (Proton)

Bei den Proton-Arten stehen mehrere Versionen in `pkgs/versions/<paket>.json`, neueste zuerst. Das Skript entfernt alte nach dieser Regel:

- alles behalten, was in den letzten 60 Tage erschienen ist,
- aber mindestens 2 Versionen (damit ein Zurück möglich bleibt),
- und höchstens 6 Versionen (damit der Speicher begrenzt bleibt).

Häufig aktualisierte Proton-Arten behalten so von selbst mehr Versionen, selten aktualisierte weniger. Die Werte lassen sich mit `KEEP_DAYS`, `MIN_KEEP` und `MAX_KEEP` ändern.

Alle behaltenen Versionen stehen unter `lib.protonVersions` (je Art `newest` und `all`, wobei `all` ein Satz aus Verzeichnisname und Paket ist, zum Beispiel für `compatibilitytools.d`).

## Aufbau

- `flake.nix`: Ausgaben (`packages`, `overlays.default`, `lib.customPackages`).
- `pkgs/`: `default.nix` (neueste Version je Paket), `proton-versions.nix` (alle Proton-Versionen), `versions/*.json` (Versionslisten), `faugus-launcher.nix`.
- `scripts/update.sh`: holt die neueste stabile Version, trägt sie ein und entfernt alte Proton-Versionen.
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
