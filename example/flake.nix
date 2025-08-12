{
  inputs = {
    xnode-manager.url = "github:Openmesh-Network/xnode-manager/dev";
    xnode-ai-chat.url = "github:OpenxAI-Network/xnode-ai-chat";
    nixpkgs.follows = "xnode-ai-chat/nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://openxai.cachix.org"
    ];
    extra-trusted-public-keys = [
      "openxai.cachix.org-1:3evd2khRVc/2NiGwVmypAF4VAklFmOpMuNs1K28bMQE="
    ];
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
