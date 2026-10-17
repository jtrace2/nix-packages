# nix-packages

Nix packages that stay current faster than nixpkgs. A daily GitHub Action checks for new upstream versions, builds them, and opens a pull request.

## Packages

| Package | Upstream |
| --- | --- |
| `faugus-launcher` | [Faugus/faugus-launcher](https://github.com/Faugus/faugus-launcher) |
| `proton-ge` | [GloriousEggroll/proton-ge-custom](https://github.com/GloriousEggroll/proton-ge-custom) |
| `proton-cachyos` | [CachyOS/proton-cachyos](https://github.com/CachyOS/proton-cachyos) (generic x86_64 build) |
| `proton-em` | [Etaash-mathamsetty/Proton](https://github.com/Etaash-mathamsetty/Proton) |
| `proton-kron4ek` | [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds) (wow64, no Staging) |

Faugus depends on `lsfg-vk`, which has an unfree license. The flake allows only that one package.

## Usage

As a flake input:

```nix
inputs.nix-packages.url = "github:jtrace2/nix-packages";
```

As an overlay (builds the packages with your system's `pkgs`):

```nix
nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
```

Or call the packages directly, with the same interface as a `custom-packages.nix`:

```nix
inputs.nix-packages.lib.customPackages { inherit pkgs lib; }
```

Build locally:

```
nix build .#faugus-launcher
```

## Retained versions (Proton)

Each Proton flavor keeps several versions in `pkgs/versions/<package>.json`, newest first. The update script removes old ones by this rule:

- keep everything released in the last 60 days,
- but at least 2 versions, so a rollback stays possible,
- and at most 6 versions, to keep disk usage bounded.

Flavors that release often keep more versions this way, rarely updated ones keep fewer. Change the values with `KEEP_DAYS`, `MIN_KEEP` and `MAX_KEEP`.

All retained versions are available as `lib.protonVersions`. Each flavor has `newest` and `all`, where `all` is a set of directory name to package (for example for `compatibilitytools.d`).

## Layout

- `flake.nix`: outputs (`packages`, `overlays.default`, `lib.customPackages`, `lib.protonVersions`).
- `pkgs/`: `default.nix` (newest version of each package), `proton-versions.nix` (all Proton versions), `versions/*.json` (version lists), `faugus-launcher.nix`.
- `scripts/update.sh`: fetches the newest stable version, records it, and drops old Proton versions.
- `.github/workflows/update.yml`: daily run, one pull request per package.

## Flow for a new version

1. The action detects a new stable release and records it.
2. The package is built. Only on success a pull request is opened.
3. Read the release notes and merge the pull request by hand. There is no automerge.
4. In your own system, update the flake (`nix flake update nix-packages`). Only then does the new version reach the system.

Check a single package without changing anything:

```
scripts/update.sh faugus-launcher --check
```

## Notes

- The repository contains no credentials and no private data.
- Only stable releases are picked up. Releases marked as pre-release, drafts, and tags that do not match the expected naming pattern are skipped.
- If no stable release matches the pattern, the script stops with an error instead of fetching an unknown file.
- The packages are plain Nix files, so the repository can move to another host at any time.

## License

The package definitions in this repository are licensed under the MIT license (see `LICENSE`). The packaged software keeps its own license.
