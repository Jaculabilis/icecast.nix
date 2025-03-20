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

  configFile = pkgs.writeText "icecast.xml" ''
    <icecast>
      <hostname>${cfg.hostname}</hostname>

      <authentication>
        <admin-user>${cfg.admin.user}</admin-user>
        <admin-password>@@ADMIN_PASSWORD@@</admin-password>
      </authentication>

      <paths>
        <logdir>${cfg.logDir}</logdir>
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
        <changeowner>
            <user>${cfg.user}</user>
            <group>${cfg.group}</group>
        </changeowner>
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

      logDir = mkOption {
        type = types.path;
        description = "Base directory used for logging.";
        default = "/var/log/icecast";
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
    users.groups.${cfg.group} = {};

    systemd.services.icecast = {
      after = [
        "network.target"
        # For some reason, icecast fails with "Could not create listener socket" if it starts before dhcpcd is ready.
        # I can't even find where that error message is logged in the source code.
        "dhcpcd.service"
      ];
      description = "Icecast Network Audio Streaming Server";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p ${cfg.logDir} && chown ${cfg.user}:${cfg.group} ${cfg.logDir}
        ${pkgs.gawk}/bin/awk -f ${substituteSecrets} ${cfg.secretsFile} ${configFile} > /tmp/icecast.xml
        grep "@@" /tmp/icecast.xml && { echo "not all secrets substituted"; exit 1; } || true
      '';
      serviceConfig = {
        Type = "simple";
        PrivateTmp = true;
        ExecStart = "${pkgs.icecast}/bin/icecast -c /tmp/icecast.xml";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "always";
        RestartSec = "3s";
        User = cfg.user;
        Group = cfg.group;
      };
    };

  };

}
