{
  description = "Xnode setup to run a local llm to chat with. Currently using Ollama and Open WebUI.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs: {
    nixosModules.default = ./nixos-module.nix;
  };
}
