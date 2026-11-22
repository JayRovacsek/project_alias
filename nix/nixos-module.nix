self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.project-alias;
in
{
  options.services.project-alias = {
    enable = lib.mkEnableOption "Project Alias voice assistant";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.project-alias;
      description = "The Project Alias application package.";
    };

    driverPackage = lib.mkOption {
      type = lib.types.package;
      default = import ./seeed-voicecard.nix { inherit lib pkgs; };
      description = "Kernel module package for the Seeed ReSpeaker microphone HAT.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/project-alias";
      description = "Directory for stateful training data.";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/etc/project-alias";
      description = "Directory for stateful application configuration.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5050;
      description = "TCP port the application listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.project-alias = {
      isSystemUser = true;
      group = "project-alias";
      home = cfg.dataDir;
    };
    users.groups.project-alias = { };

    # Make the out-of-tree HAT driver available and load it at boot.
    boot.extraModulePackages = [ cfg.driverPackage ];
    boot.kernelModules = [
      "snd-soc-wm8960"
      "snd-soc-ac108"
      "snd-soc-seeed-voicecard"
    ];

    # The only privileged unit: a netfilter redirect that replaces the old
    # rc.local/sleep.py behaviour. Kept separate from the untrusted app unit
    # so the app itself needs no capabilities.
    systemd.services.project-alias-iptables = {
      description = "Project Alias port redirect";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "+${pkgs.coreutils}/bin/sleep 5";
        ExecStart = "+${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port ${toString cfg.port}";
        ExecStop = "+${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port ${toString cfg.port}";
        CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW";
        ProtectSystem = "strict";
      };
    };

    # Untrusted application unit: confined to its own state and config dirs,
    # no privilege escalation.
    systemd.services.project-alias = {
      description = "Project Alias application";
      wantedBy = [ "multi-user.target" ];
      after = [ "project-alias-iptables.service" ];
      wants = [ "project-alias-iptables.service" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/project-alias";
        User = "project-alias";
        Group = "project-alias";
        StateDirectory = "project-alias";
        ConfigurationDirectory = "project-alias";
        Environment = [
          "PROJECT_ALIAS_SETTINGS=${cfg.configDir}/settings.txt"
          "PROJECT_ALIAS_KEYWORD=${cfg.dataDir}/keyphrase.list"
          "PORT=${toString cfg.port}"
        ];
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        # Explicit, minimal device access for the HAT instead of PrivateDevices.
        DevicePolicy = "strict";
        DeviceAllow = [
          "/dev/snd/pcmC0D0p"
          "/dev/snd/controlC0"
          "/dev/snd/timer"
          "/dev/spidev0.0"
        ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        LockPersonality = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = "AF_INET AF_INET6";
        SystemCallFilter = "@system-service";
        SystemCallErrorNumber = "EPERM";
        UMask = "0027";
      };
    };
  };
}
