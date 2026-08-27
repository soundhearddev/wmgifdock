{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  name = "wmgifdock";
  src = ./.;

  buildInputs = with pkgs; [
    gcc
    gnumake
    pkg-config
    libX11
    libXext
    libXpm
    imlib2
    imagemagick
    boost # Nur zum compilieren nötig
  ];

  buildPhase = "make clean && make";
  installPhase = "mkdir -p $out/bin && cp wmgifdock $out/bin/";

  # Runtime dependencies
  propagatedBuildInputs = with pkgs; [
    libX11
    libXext
    libXpm
    imlib2
    imagemagick
  ];
}
