{
  description = "Custom icecast module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-shell.url = "github:Mic92/nixos-shell";
    nixos-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-shell,
      ...
    }:
    let
      inherit (nixpkgs.lib) nixosSystem;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      packages.${system}.demo-source = import ./source.nix { inherit pkgs; };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          icecast
          liquidsoap
          pkgs.nixos-shell
        ];
      };

      apps.${system}.demo-source = {
        type = "app";
        program = "${self.packages.${system}.demo-source}/bin/demo-source";
      };

      nixosModules.default = import ./module.nix;

      nixosConfigurations."demo" = nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.default
          ./demo.nix
        ];
      };
    };
}
