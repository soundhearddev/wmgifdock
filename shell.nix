{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  name = "wmgifdock-dev";

  buildInputs = with pkgs; [
    gcc
    gnumake
    pkg-config
    libX11
    libXext
    libXpm
    imlib2
    imagemagick
    boost
  ];

  shellHook = ''
    echo "Run: make clean && make"
  '';
}
