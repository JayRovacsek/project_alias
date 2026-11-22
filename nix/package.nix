{
  lib,
  python3Packages,
  src,
}:

let
  # Single interpreter bundling every runtime dependency the app imports;
  # the interpreter choice (3.13, as tensorflow is bin-only and broken on
  # 3.14) lives in the flake, not here.
  python = python3Packages.python.withPackages (
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
python3Packages.stdenvNoCC.mkDerivation {
  pname = "project-alias";
  version = "2.0";
  inherit src;

  nativeBuildInputs = [ python3Packages.makeWrapper ];

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
          python3Packages.espeak-ng
          python3Packages.alsa-utils
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
