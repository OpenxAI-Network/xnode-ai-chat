{
  description = "Xnode setup to run a local llm to chat with. Currently using Ollama and Open WebUI.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      ...
    }@inputs:
    {
      nixosModules.default = import ./nixos-module.nix inputs;
    };
}
