{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
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
      <hostname>localhost</hostname>

      <authentication>
        <admin-user>admin</admin-user>
        <admin-password>@@ADMIN_PASSWORD@@</admin-password>
      </authentication>

      <paths>
        <logdir>/var/log/icecast</logdir>
        <adminroot>${pkgs.icecast}/share/icecast/admin</adminroot>
        <webroot>${pkgs.icecast}/share/icecast/web</webroot>
        <alias source="/" dest="/status.xsl"/>
      </paths>

      <listen-socket>
        <port>8000</port>
        <bind-address>0.0.0.0</bind-address>
      </listen-socket>

      <security>
        <chroot>0</chroot>
        <changeowner>
            <user>nobody</user>
            <group>nogroup</group>
        </changeowner>
      </security>
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
      secretsFile = mkOption {
        type = types.str;
        description = ''
          Path to a file containing secrets in the form NAME=VALUE.
          These will be substituted into the config for each occurrence of "@@NAME@@".
          It must contain the admin password as ADMIN_PASSWORD=...
        '';
      };
    };

  };

  # Module implementation
  config = {

    systemd.services.icecast = {
      after = [ "network.target" ];
      description = "Icecast Network Audio Streaming Server";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p /var/log/icecast && chown nobody:nogroup /var/log/icecast
        ${pkgs.gawk}/bin/awk -f ${substituteSecrets} ${cfg.secretsFile} ${configFile} > /tmp/icecast.xml
        grep "@@" /tmp/icecast.xml && { echo "not all secrets substituted"; exit 1; } || true
      '';
      serviceConfig = {
        Type = "simple";
        PrivateTmp = true;
        ExecStart = "${pkgs.icecast}/bin/icecast -c /tmp/icecast.xml";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };
    };

  };

}
