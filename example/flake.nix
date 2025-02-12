{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    xnode-ai-chat = {
      url = "github:OpenxAI-Network/xnode-ai-chat";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    };
  };

  outputs =
    {
      self,
      nixpkgs-stable,
      xnode-ai-chat,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.container = nixpkgs-stable.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit xnode-ai-chat;
        };
        modules = [
          (
            { xnode-ai-chat, ... }:
            {
              imports = [
                xnode-ai-chat.nixosModules.default
              ];

              boot.isContainer = true;

              services.xnode-ai-chat = {
                enable = true;
                defaultModel = "deepseek-r1";
                admin = {
                  name = "Samuel";
                  email = "plopmenz@gmail.com";
                  password = "demo";
                };
              };

              networking = {
                firewall.allowedTCPPorts = [ 8080 ];
              };

              system.stateVersion = "24.11";
            }
          )
        ];
      };
    };
}
