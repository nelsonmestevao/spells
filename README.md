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

So a spell needs nothing installed but nix.

A few tools cannot come from nix, such as `git` (kept from your system so it
uses your credentials) or `gsettings`. Spells that use one say so at the end
of their `--help`, under "Needs from your system".

### Shared helpers

`lib/spellbook.xsh` holds the code that xonsh spells would otherwise each
copy. A spell then holds only its own logic.

| Helper | What it does |
|---|---|
| `success`, `failure` | Print a line that ends in a green ✓ or a red ✗. |
| `error` | Print a line that ends in a red ✗, and stop the spell. |
| `log_info`, `log_warn` | Print a note, or a warning. |
| `parse_args` | Read the command line against the docstring of the spell. |
| `ask`, `pick` | Ask with gum. A cancelled prompt ends the spell quietly. |
| `spin` | Run a command behind a gum spinner. |
| `step` | The same, and then say whether it worked. |
| `default_branch` | Find the default branch of a git remote. |

`spl new` writes a spell that imports a few of them. Add or drop names as
you need:

```python
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "lib"))
from spellbook import error, log_info, log_warn, parse_args, success
```

A spell that does this needs the `lib` folder next to it. To use it on
another machine, clone this repo there. The bash, sh and python spells are
still one file each.

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

This moves every spell to the newest `nixpkgs-unstable` commit. Nothing runs
it for you: run it when you want newer packages, then open a pull request. The
tests run on that pull request, on Linux and macOS, so you see whether the
update breaks a spell before you merge it.

`spl bump <commit>` moves to a commit you pick, for example to go back.

## Writing a spell

```sh
spl new my-spell
```

This makes `my-spell` from a template, with the header above, and opens it in
your editor. `spl edit` opens an existing spell.

A spell starts with one line that says what it does: the first line of its
docstring, or a comment right under the header.

### Versions

A spell with a `--version` option carries its own number. Bump it in the pull
request that changes the spell:

| The change | For example | The number |
|---|---|---|
| A new feature | a new option, one more system it works on | `0.3.2` becomes `0.4.0` |
| A fix | a crash, a wrong answer | `0.3.2` becomes `0.3.3` |
| A break in how you call it | an option renamed or removed | `0.3.2` becomes `1.0.0` |
| Nothing you can see from outside | a tidy-up, a newer nixpkgs | stays as it is |

A new spell starts at `0.1.0`.

## Tests

```sh
tests/run
```

This runs every script in `tests/`. GitHub Actions runs the same command for
every pull request: through `shims/nix-shell` on Linux and macOS, and with
plain `nix-shell` on Linux.
