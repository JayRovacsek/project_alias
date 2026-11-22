{ lib, pkgs, ... }:

# Seeed ReSpeaker microphone HAT driver. The upstream Makefile has a
# KERNELRELEASE branch with obj-m entries, so kbuild (buildOutOfTreeModule)
# builds it directly.
pkgs.linuxPackages.buildOutOfTreeModule {
  name = "seeed-voicecard";
  src = pkgs.fetchFromGitHub {
    owner = "respeaker";
    repo = "seeed-voicecard";
    rev = "c52606626de050bdad85803d7e427a64cb0cf05c";
    hash = "sha256-sFReX9Nz9TDRvheKfPijRw1wQ++jJUk5+lOwVmfx3wA=";
  };
  meta = {
    description = "Seeed ReSpeaker microphone HAT kernel driver";
    platforms = lib.platforms.linux;
  };
}
