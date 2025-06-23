{
  inputs = {
    xnode-manager.url = "github:Openmesh-Network/xnode-manager";
    xnode-ai-chat.url = "github:OpenxAI-Network/xnode-ai-chat";
    nixpkgs.follows = "xnode-ai-chat/nixpkgs";
  };

  outputs = inputs: {
    nixosConfigurations.container = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      modules = [
        inputs.xnode-manager.nixosModules.container
        {
          services.xnode-container.xnode-config = {
            host-platform = ./xnode-config/host-platform;
            state-version = ./xnode-config/state-version;
            hostname = ./xnode-config/hostname;
          };
        }
        inputs.xnode-ai-chat.nixosModules.default
        {
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
            hostName = "xnode-ai-chat";
            firewall.allowedTCPPorts = [ 8080 ];
          };
        }
      ];
    };
  };
}
