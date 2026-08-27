{
  description = "wmgifdock - A GIF dock for windowmaker/afterstep-style docks.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = fn: nixpkgs.lib.genAttrs systems (system: fn nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: rec {
      default = pkgs.callPackage ./default.nix {};
      wmgifdock = default;
    });
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        inputsFrom = [self.packages.${pkgs.stdenv.hostPlatform.system}.wmgifdock];
        shellHook = ''
          echo "Run: make clean && make"
        '';
      };
    });
    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
