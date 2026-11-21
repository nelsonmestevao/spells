# Collection of Spells :crystal_ball:

[![tests](https://github.com/nelsonmestevao/spells/actions/workflows/tests.yml/badge.svg)](https://github.com/nelsonmestevao/spells/actions/workflows/tests.yml)

This repository contains ordinary scripts for shell that I like to call spells.

## Setup

You need [nix](https://nixos.org/download). Then:

```sh
git clone https://github.com/nelsonmestevao/spells ~/.spells
```

```sh
# in ~/.zshrc
export SPELLS="$HOME/.spells"
source "$SPELLS/spells.init"
```

`spells.init` puts the spells on your `PATH`.

## How a spell works

A spell is one file. Its first lines say everything it needs:

```sh
#!/usr/bin/env nix-shell
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/680275f0bb6afce84fbac3e75fc47c5f2272400b.tar.gz
#! nix-shell -p gum python313 python313Packages.xonsh python313Packages.docopt
#! nix-shell -i xonsh
```

- **Line 2** names one exact commit of nixpkgs. Every spell uses the same one,
  so a spell runs the same on every machine until that line changes.
- **Line 3** lists the packages the spell uses.
- **Line 4** names the program that runs the rest of the file.

So a spell needs nothing installed but nix. You can copy one file to another
machine and run it.

A few tools cannot come from nix, such as `git` (kept from your system so it
uses your credentials) or `gsettings`. Spells that use one say so at the end
of their `--help`, under "Needs from your system".

## Fast starts

Nix works out a spell's environment on every run. That takes about a second,
even when nothing changed.

`shims/nix-shell` fixes that. `spells.init` puts it first on your `PATH`, so it
runs in place of the real `nix-shell`. The first time it sees a header, it
lets the real one build the environment and remembers the result. After that
it starts the spell directly.

| Warm run on a Mac | Without | With |
|---|---|---|
| `cowecho hi` (bash) | 0.94s | 0.07s |
| `hexdiff --version` (xonsh) | 1.25s | 0.17s |

The spells do not depend on it. Take `shims` off your `PATH` and they still
run, just slower.

- Skip it for one run: `NIX_SHELL_CACHE=off some-spell`
- Start fresh: `rm -rf ~/.cache/nix-shell-cache`
- It also speeds up any other script that starts with `#!/usr/bin/env nix-shell`.

## Staying on the latest nixpkgs

```sh
spl bump
```

This moves every spell to the newest `nixpkgs-unstable` commit. A workflow
runs it every Monday and opens a pull request. The tests run on that pull
request, so you see whether an update breaks a spell before you merge it.

## Writing a spell

```sh
spl new my-spell
```

This makes `my-spell` from a template, with the header above, and opens it in
your editor. `spl edit` opens an existing spell.

## Tests

```sh
tests/run
```

This runs every script in `tests/`. GitHub Actions runs the same command on
Linux and macOS for every pull request, once as it is and once through
`shims/nix-shell`.
