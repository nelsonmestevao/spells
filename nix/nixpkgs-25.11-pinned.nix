import (builtins.fetchTarball {
  # $ get_nix_channel_revision 25.11
  url = "https://github.com/NixOS/nixpkgs/archive/fea3b367d61c1a6592bc47c72f40a9f3e6a53e96.tar.gz";
  # $ nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/$(get_nix_channel_revision 25.11).tar.gz 2>/dev/null
  sha256 = "01py97nq5ss8kfkmcs8zmmahmcd6ykcjjb2kivgp5b36hji3xm8q";
}) {}