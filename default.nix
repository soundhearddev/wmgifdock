{
  lib,
  stdenv,
  gcc,
  gnumake,
  pkg-config,
  libX11,
  libXext,
  libXpm,
  imlib2,
  imagemagick,
  boost,
}:
stdenv.mkDerivation {
  pname = "wmgifdock";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    gcc
    gnumake
    pkg-config
  ];

  buildInputs = [
    libX11
    libXext
    libXpm
    imlib2
    imagemagick
    boost
  ];

  buildPhase = "make clean && make";

  installPhase = ''
    mkdir -p $out/bin
    cp wmgifdock $out/bin/
  '';

  meta = {
    description = "GIF dock for windowmaker";
    platforms = lib.platforms.linux;
    mainProgram = "wmgifdock";
  };
}
