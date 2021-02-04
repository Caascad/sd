{ sources ? import ./nix/sources.nix
, toolboxSrc ? sources.toolbox
, toolbox ? import toolboxSrc {}
}:

with toolbox;

toolbox.pkgs.stdenv.mkDerivation {
    pname = "discovery";
    version = "0.0.1";
    unpackPhase = "true";
    src="./src";
    buildInputs = [
      vault
      curl
      jq
      cue
      pkgs.stdenv
    ];
    installPhase = ''
      install -m755 -D ${./src/bin/sd.sh} $out/bin/sd
      install -m444 -D ${./src/share/schema.cue} $out/share/schema.cue
    '';
  }
