{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixos-shell.mounts = {
    mountHome = false;
    mountNixProfile = false;
    cache = "none";
  };

  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 8000;
      guest.port = 8000;
    }
  ];

  environment.etc."icecast-secrets".text = ''
    ADMIN_PASSWORD=secure
  '';

  system.stateVersion = "24.11";
}

