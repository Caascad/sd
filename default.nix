{ sources ? import ./nix/sources.nix
, pkgs ? import sources.nixpkgs {}
, lib ? pkgs.lib
}:

let

  deps = with pkgs; lib.makeBinPath [ vault curl jq cue awscli ];

in pkgs.stdenv.mkDerivation rec {
  pname = "discovery";
  version = "1.0.5";

  unpackPhase = "true";
  buildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    install -m755 -D ${./src/bin/sd.sh} $out/bin/sd
    install -m444 -D ${./src/share/schema.cue} $out/share/schema.cue

    wrapProgram $out/bin/sd --prefix PATH ":" ${deps}
  '';

  meta = with lib; {
    description = "Service discovery";
    homepage = "https://github.com/Caascad/sd";
    license = licenses.mit;
    maintainers = with maintainers; [ "Benjile" ];
  };
}
