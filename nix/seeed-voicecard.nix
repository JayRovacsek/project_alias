{ lib, pkgs, ... }:

let
  kernel = pkgs.linuxPackages.kernel;
  kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
# buildOutOfTreeModule was removed from linuxPackages in this nixpkgs, so
# invoke kbuild directly against the kernel dev tree; that selects the
# Makefile's KERNELRELEASE obj-m branch.
kernel.stdenv.mkDerivation {
  pname = "seeed-voicecard";
  version = "unstable-2021-11-25";

  src = pkgs.fetchFromGitHub {
    owner = "respeaker";
    repo = "seeed-voicecard";
    rev = "c52606626de050bdad85803d7e427a64cb0cf05c";
    hash = "sha256-sFReX9Nz9TDRvheKfPijRw1wQ++jJUk5+lOwVmfx3wA=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  buildPhase = ''
    runHook preBuild
    make -C ${kdir} M=$(pwd) modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C ${kdir} M=$(pwd) INSTALL_MOD_PATH=${placeholder "out"} modules_install
    runHook postInstall
  '';

  meta = {
    description = "Seeed ReSpeaker microphone HAT kernel driver";
    platforms = lib.platforms.linux;
  };
}
