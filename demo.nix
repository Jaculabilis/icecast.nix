{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Icecast demo config

  # Normally you'd put these somewhere secret
  environment.etc."icecast-secrets".text = ''
    ADMIN_PASSWORD=secure
  '';

  services.icecast = {
    enable = true;
    listen.address = "0.0.0.0";
    # Point this to your secrets file
    secretsFile = "/etc/icecast-secrets";
    extraConf = ''
      <location>A NixOS container</location>
    '';
  };

  # Demo VM config
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nixos-shell.mounts.mountHome = false;
  nixos-shell.mounts.mountNixProfile = false;
  nixos-shell.mounts.cache = "none";
  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 8000;
      guest.port = 8000;
    }
  ];
  system.stateVersion = "24.11";
}

