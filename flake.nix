{
  description = "wmgifdock";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          wmgifdock = pkgs.callPackage ./default.nix { };
          default = self.packages.${system}.wmgifdock;
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              zig
              zls
              pkg-config
            ];

            buildInputs = with pkgs; [
              libX11
              libXext
              imlib2
            ];

            shellHook = ''
              echo "wmgifdock Zig dev environment active."
              echo "Commands: 'zig build' or 'zig build run'"
            '';
          };
        }
      );

      formatter = forAllSystems (system:
        nixpkgs.legacyPackages.${system}.alejandra
      );
    };
}