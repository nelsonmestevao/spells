let
  pkgs = import ../nixpkgs-25.11-pinned.nix;
in
pkgs.mkShell {
  packages = with pkgs; [
    gum
    python313
    python313Packages.xonsh
    python313Packages.docopt
  ];
}