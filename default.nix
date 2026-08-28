{ lib
, stdenv
, zig
, pkg-config
, libX11
, libXext
, imlib2
}:

stdenv.mkDerivation {
  pname = "wmgifdock";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [
    zig
    pkg-config
  ];

  buildInputs = [
    libX11
    libXext
    imlib2
  ];

  meta = {
    description = "GIF dock app for Window Maker";
    homepage = "https://github.com/soundhearddev/wmgifdock";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "wmgifdock";
  };
}