{
  config,
  lib,
  pkgs,
  ...
}:

let

  configFile = pkgs.writeText "icecast.xml" ''
    <icecast>
      <hostname>localhost</hostname>

      <authentication>
        <admin-user>admin</admin-user>
        <admin-password>hackme</admin-password>
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

  config = {

    systemd.services.icecast = {
      after = [ "network.target" ];
      description = "Icecast Network Audio Streaming Server";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p /var/log/icecast && chown nobody:nogroup /var/log/icecast
        cp ${configFile} /tmp/icecast.xml
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
