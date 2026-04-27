{
  description = "Nix package for CodeBurn - See where your AI coding tokens go";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        codeburn = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.codeburn;
          codeburn = pkgs.codeburn;
        };

        apps.default = {
          type = "app";
          program = "${pkgs.codeburn}/bin/codeburn";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch-url
          ];
        };
      }) // {
      overlays.default = overlay;
    };
}
