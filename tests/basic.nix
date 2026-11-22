{ self, pkgs }:

pkgs.testers.runNixOSTest {
  name = "project-alias-basic";

  nodes.machine = { lib, ... }: {
    imports = [ self.nixosModules.project-alias ];

    environment.systemPackages = [ pkgs.curl ];

    # The ReSpeaker driver is hardware-specific and irrelevant to this
    # operational test, so keep it out of the VM.
    boot.kernelModules = lib.mkForce [ ];
    boot.extraModulePackages = lib.mkForce [ ];

    services.project-alias = {
      enable = true;
      # The real package targets aarch64 only and drags in tensorflow; stub
      # the entrypoint with a stdlib http server that honours $PORT so the
      # test exercises the unit wiring, sandbox and iptables behaviour on
      # x86_64.
      package = pkgs.writeShellScriptBin "project-alias" ''
        exec ${pkgs.python3}/bin/python3 -m http.server "''${PORT:-5050}" --bind 0.0.0.0
      '';
    };
  };

  testScript = ''
    start_all()

    with subtest("units are active"):
        machine.wait_until_succeeds("systemctl is-active --quiet project-alias.service")
        machine.wait_until_succeeds("systemctl is-active --quiet project-alias-iptables.service")

    with subtest("service user and state dirs exist"):
        machine.succeed("id project-alias")
        machine.succeed("test -d /var/lib/project-alias")
        machine.succeed("test -d /etc/project-alias")
        machine.succeed('test "$(stat -c %U /var/lib/project-alias)" = "project-alias"')

    with subtest("nat redirect rule installed"):
        machine.succeed("iptables -t nat -S PREROUTING | grep -q 'REDIRECT --to-port 5050'")

    with subtest("sandbox hardening is active"):
        machine.succeed("systemctl show project-alias.service -p NoNewPrivileges | grep -q 'NoNewPrivileges=yes'")
        machine.succeed("systemctl show project-alias.service -p CapabilityBoundingSet | grep -q '^CapabilityBoundingSet=$'")

    with subtest("app port is reachable"):
        machine.wait_until_succeeds("curl -sf http://127.0.0.1:5050/ >/dev/null")

    with subtest("stopping the iptables unit removes the rule"):
        machine.succeed("systemctl stop project-alias-iptables.service")
        machine.succeed("! iptables -t nat -S PREROUTING | grep -q 'REDIRECT --to-port 5050'")
  '';
}
