let
  sources = import ./nix/sources.nix;
  toolboxSrc = sources.toolbox;
  toolbox = import toolboxSrc {};
  discovery = toolbox.pkgs.callPackage ./default.nix {};

in
  toolbox.pkgs.runCommand "deps" {
    buildInputs = [
      discovery
    ];
  } ""
