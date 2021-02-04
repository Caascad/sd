{ sources ? import ./nix/sources.nix 
, nixpkgs ? sources.nixpkgs 
, toolbox ? sources.toolbox 
, pkgs ? import nixpkgs {} 
, tbox ? import toolbox {} 
}: 

with pkgs;
with pkgs.lib;

stdenv.mkDerivation rec {
    pname = "discovery";
    version = "1.0.0";
    unpackPhase = "true";
    src="./src";
    buildInputs = [
      tbox.vault
      curl
      jq
      tbox.cue
      stdenv
    ];
    installPhase = ''
      install -m755 -D ${./src/bin/sd.sh} $out/bin/sd
      install -m444 -D ${./src/share/schema.cue} $out/share/schema.cue
    '';
    meta = with stdenv.lib; { 
    description = "service discovery"; 
    homepage = "https://github.com/Caascad/sd"; 
    license = licenses.mit; 
    maintainers = with maintainers; [ "Benjile" ]; 
  }; 

  }
