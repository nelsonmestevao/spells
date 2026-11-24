"""
Helpers shared by the xonsh spells: messages, the command line, prompts, git.

A spell loads the ones it uses with two lines near its top:

    sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "lib"))
    from spellbook import error, success, parse_args

A spell in a subfolder, such as git/, puts ".." before "lib".

The prompt helpers run gum, and parse_args needs docopt. Both come from the
nix-shell header of the spell.
"""

from docopt import docopt, DocoptExit
from subprocess import CalledProcessError

import os
import sys


RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"


# --- Messages ----------------------------------------------------------------

def success(msg):
    print(f"{msg} {GREEN}✓{RESET}")

def failure(msg):
    """Say that a step went wrong, and carry on."""
    print(f"{msg} {RED}✗{RESET}", file=sys.stderr)

def error(msg):
    """Say what went wrong, and stop the spell."""
    failure(msg)
    sys.exit(1)

def log_warn(msg):
    print(f"{YELLOW}▲{RESET} {msg}", file=sys.stderr)

def log_info(msg):
    print(f"{BLUE}◆{RESET} {msg}")


# --- The command line --------------------------------------------------------

def parse_args(doc, file, version, argv=None):
    """
    Read the command line with docopt and return the arguments.

    doc is the docstring of the spell, file its __file__, and version a string
    such as "0.1.0". Pass argv when the spell reads only a part of sys.argv.
    """
    try:
        # Only the name, as you type it, not the path to the file.
        program = os.path.basename(file)
        return docopt(doc.format(program=program), argv=argv, version=f"{program} v{version}")
    except DocoptExit as wrong_usage:
        # xonsh takes docopt's exit for a crash and prints a traceback hint
        # above the usage. A plain SystemExit prints only the usage.
        sys.exit(wrong_usage.code)


# --- Prompts and spinners ----------------------------------------------------
# gum fails when a prompt is cancelled with Esc or Ctrl-C. The spell then stops
# quietly, with the exit status of gum and no traceback.

def ask(*gum_args):
    """Run a gum prompt, such as ask("choose", "on", "off"), and return the answer."""
    try:
        return $(gum @(gum_args)).strip()
    except CalledProcessError as cancelled:
        sys.exit(cancelled.returncode)

def pick(lines, placeholder):
    """Let the user search a list of lines and pick one. Returns that line."""
    try:
        return $(echo @("\n".join(lines)) | gum filter --placeholder @(placeholder)).strip()
    except CalledProcessError as cancelled:
        sys.exit(cancelled.returncode)

def spin(title, argv):
    """Run argv behind a spinner. True when it worked. When it fails, gum shows its output."""
    return bool(![gum spin --align=right --title @(f"{title}...") --show-error -- @(argv)])

def step(title, argv):
    """Run argv behind a spinner, then say how it went. True when it worked."""
    worked = spin(title, argv)
    if worked:
        success(title)
    else:
        failure(title)
    return worked


# --- git ---------------------------------------------------------------------

def default_branch(remote="origin"):
    """The default branch of the remote: what its HEAD points at, or main, or master."""
    head = !(git symbolic-ref --short @(f"refs/remotes/{remote}/HEAD"))
    if head.returncode == 0:
        return head.out.strip().removeprefix(f"{remote}/")

    # A repo that was not cloned has no <remote>/HEAD. Look for the branch itself.
    for name in ("main", "master"):
        for ref in (f"refs/remotes/{remote}/{name}", f"refs/heads/{name}"):
            if !(git show-ref --verify --quiet @(ref)).returncode == 0:
                return name
    return "main"
