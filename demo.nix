{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 8000;
      guest.port = 8000;
    }
  ];

  system.stateVersion = "24.11";
}

