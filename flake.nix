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
            inputsFrom = [
              self.packages.${system}.wmgifdock
            ];

            packages = with pkgs; [
              zig
              zls
            ];

            shellHook = ''
              echo "wmgifdock Zig dev environment active."
              echo "Execute: 'zig build -Doptimize=ReleaseSafe'"
            '';
          };
        }
      );

      formatter = forAllSystems (system:
        nixpkgs.legacyPackages.${system}.alejandra
      );
    };
}
