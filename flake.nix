{
  description = "NixOS: Ryzen 5 5600H + GTX 1650, niri + Noctalia + SDDM (astronaut)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/9996594bd38077de6a018ec17453ba3d99182787";
    freesmlauncher = {
      url = "github:FreesmTeam/FreesmLauncher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, freesmlauncher, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
      # Передаём freesmlauncher в модули, чтобы он был доступен в configuration.nix
      specialArgs = { inherit freesmlauncher; };
    };
  };
}
