{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos";
    xnode-ai-chat.url = "github:OpenxAI-Network/xnode-ai-chat/cache";
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
        inputs.xnodeos.nixosModules.container
        {
          services.xnode-container.xnode-config = ./xnode-config;
        }
        inputs.xnode-ai-chat.nixosModules.default
        (
          { pkgs, ... }@args:
          {
            # START USER CONFIG
            services.xnode-ai-chat.defaultModel = "deepseek-r1";
            # END USER CONFIG

            services.xnode-ai-chat = {
              enable = true;
              autoGenerate.enable = false;
            };

            services.ollama.package = pkgs.ollama-cpu;

            networking.firewall.allowedTCPPorts = [ 8080 ];
          }
        )
      ];
    };
  };
}
