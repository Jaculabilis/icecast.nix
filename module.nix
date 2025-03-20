{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    mkRemovedOptionModule
    types
    ;

  cfg = config.services.icecast;

  # This awk script reads KEY=VALUE pairs from the first input file and
  # substitutes all @@KEY@@ with VALUE in the second file. This is used to
  # inject secrets into a private copy of the config file from /nix/store.
  substituteSecrets = pkgs.writeText "substitute-secrets.awk" ''
    NR == FNR {
      split($0, kv, "=")
      secrets[kv[1]] = kv[2]
      next
    }
    {
      for (key in secrets) {
        gsub("@@" key "@@", secrets[key])
      }
      print
    }
  '';

  # The globally-readable config file in /nix/store.
  # All secrets are referenced by @@NAME@@ and injected at service start.
  configFile = pkgs.writeText "icecast.xml" ''
    <icecast>
      <hostname>${cfg.hostname}</hostname>

      <authentication>
        <admin-user>${cfg.admin.user}</admin-user>
        <admin-password>@@ADMIN_PASSWORD@@</admin-password>
      </authentication>

      <paths>
        <logdir>/var/log/icecast</logdir>
        <adminroot>${pkgs.icecast}/share/icecast/admin</adminroot>
        <webroot>${pkgs.icecast}/share/icecast/web</webroot>
        <alias source="/" dest="/status.xsl"/>
      </paths>

      <listen-socket>
        <port>${toString cfg.listen.port}</port>
        <bind-address>${cfg.listen.address}</bind-address>
      </listen-socket>

      <security>
        <chroot>0</chroot>
      </security>

      ${cfg.extraConf}
    </icecast>
  '';
in
{
  # Disable the upstream module and warn for removed options
  disabledModules = [ "services/audio/icecast.nix" ];
  imports = [
    (mkRemovedOptionModule [ "services" "icecast" "admin" "password" ] ''
      Instead of specifying a cleartext password, add the password to the file named in `services.icecast.secretsFile`.
    '')
  ];

  # Module interface
  options = {

    services.icecast = {
      enable = mkEnableOption "Icecast network audio streaming server";

      hostname = mkOption {
        type = types.str;
        description = "DNS name or IP address that will be used for the stream directory lookups or possibly the playlist generation if a Host header is not provided.";
        default = "localhost";
      };

      secretsFile = mkOption {
        type = types.str;
        description = ''
          Path to a file containing secrets in the form NAME=VALUE.
          These will be substituted into the config for each occurrence of "@@NAME@@".
          It must contain the admin password as ADMIN_PASSWORD=...
        '';
      };

      admin = {
        user = mkOption {
          type = types.str;
          description = "Username used for all administration functions.";
          default = "admin";
        };
      };

      listen = {
        port = mkOption {
          type = types.port;
          description = "TCP port that will be used to accept client connections.";
          default = 8000;
        };

        address = mkOption {
          type = types.str;
          description = "Address Icecast will listen on.";
          default = "127.0.0.1";
        };
      };

      user = mkOption {
        type = types.str;
        description = "User for the server.";
        default = "icecast";
      };

      group = mkOption {
        type = types.str;
        description = "Group for the server.";
        default = "icecast";
      };

      extraConf = mkOption {
        type = types.lines;
        description = "icecast.xml content.";
        default = "";
      };
    };

  };

  # Module implementation
  config = mkIf cfg.enable {

    users.users.${cfg.user} = {
      group = cfg.group;
      description = "Icecast service user";
      isSystemUser = true;
    };
    users.groups.${cfg.group} = { };

    systemd.services.icecast = {
      after = [
        "network.target"
      ];
      description = "Icecast Network Audio Streaming Server";
      wantedBy = [ "multi-user.target" ];
      # This is where the secret substitution occurs
      preStart = ''
        ${pkgs.gawk}/bin/awk -f ${substituteSecrets} ${cfg.secretsFile} ${configFile} > /tmp/icecast.xml
        grep "@@" /tmp/icecast.xml && { echo "not all secrets substituted"; exit 1; } || true
      '';
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.icecast}/bin/icecast -c /tmp/icecast.xml";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "always";
        RestartSec = "3s";
        User = cfg.user;
        Group = cfg.group;
        LogsDirectory = "icecast";
        # Hardening options
        # See https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html
        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "full";
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
      };
    };

  };

}
