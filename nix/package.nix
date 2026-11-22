{
  lib,
  pkgs,
  src,
}:

let
  # Single interpreter bundling every runtime dependency the app imports.
  # Pinned to 3.13: tensorflow's dependency chain (google-pasta) is broken
  # on nixpkgs' default python3 (3.14).
  python = pkgs.python313.withPackages (
    ps: with ps; [
      flask
      flask-socketio
      pocketsphinx
      pygame
      spidev
      keras
      tensorflow
    ]
  );
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "project-alias";
  version = "2.0";
  inherit src;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/project-alias $out/bin
    cp -r ${src}/app.py ${src}/modules ${src}/data ${src}/imgs ${src}/LICENSE.GPL $out/share/project-alias

    makeWrapper ${python}/bin/python3 $out/bin/project-alias \
      --add-flags "$out/share/project-alias/app.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.espeak-ng
          pkgs.alsa-utils
        ]
      }

    runHook postInstall
  '';

  passthru = { inherit python; };

  meta = {
    description = "Rename your assistant and make sure it never listens";
    license = lib.licenses.gpl3Plus;
    platforms = [ "aarch64-linux" ];
  };
}
