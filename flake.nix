{
  description = "NixOS: Ryzen 5 5600H + GTX 1650, niri + Noctalia + SDDM (astronaut)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/9996594bd38077de6a018ec17453ba3d99182787";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.cachy = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
