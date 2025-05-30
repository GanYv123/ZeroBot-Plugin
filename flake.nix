{
  description = "基于 ZeroBot 的 OneBot 插件";

  inputs.nixpkgs-with-go_1_20.url = "github:NixOS/nixpkgs/33c51330782cb486764eb598d5907b43dc87b4c2";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.gomod2nix.url = "github:nix-community/gomod2nix";
  inputs.gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.gomod2nix.inputs.flake-utils.follows = "flake-utils";

  outputs = {
    self,
    nixpkgs,
    nixpkgs-with-go_1_20,
    flake-utils,
    gomod2nix,
    ...
  } @ inputs: let
    allSystems = flake-utils.lib.allSystems;
  in (
    flake-utils.lib.eachSystem allSystems
    (system: let
      old-nixpkgs = nixpkgs-with-go_1_20.legacyPackages.${system};
      pkgs = import nixpkgs {
        inherit system;

        overlays = [
          (_: _: {
            go_1_20 = old-nixpkgs.go_1_20;
          })
        ];
      };

      # The current default sdk for macOS fails to compile go projects, so we use a newer one for now.
      # This has no effect on other platforms.
      callPackage = pkgs.darwin.apple_sdk_11_0.callPackage or pkgs.callPackage;
    in {
      # doCheck will fail at write files
      packages = rec {
        ZeroBot-Plugin = (callPackage ./. (inputs
          // {
            inherit (gomod2nix.legacyPackages.${system}) buildGoApplication;
          }))
          .overrideAttrs (_: {doCheck = false;});

        default = ZeroBot-Plugin;

        docker_builder = pkgs.dockerTools.buildLayeredImage {
          name = "ZeroBot-Plugin";
          tag = "latest";
          contents = [
            self.packages.${system}.ZeroBot-Plugin
            pkgs.cacert
          ];
        };
      };
      devShells.default = callPackage ./shell.nix {
        inherit (gomod2nix.legacyPackages.${system}) mkGoEnv gomod2nix;
      };
      formatter = pkgs.alejandra;
    })
  );
}
