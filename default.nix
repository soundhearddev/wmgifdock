{ lib
, stdenv
, zig
, pkg-config
, libX11
, libXext
, imlib2
, linkFarm
, fetchzip
, fetchgit
}:

let
  zigPackages = import ./deps.nix {
    inherit linkFarm fetchzip fetchgit;
  };
in
stdenv.mkDerivation {
  pname = "wmgifdock";
  version = "0.1.0";

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

  postPatch = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p"
    ln -s ${zigPackages} "$ZIG_GLOBAL_CACHE_DIR/p/dep" # oder entsprechend verknüpfen
  '';


  buildPhase = ''
    runHook preBuild

    zig build \
      -j$NIX_BUILD_CORES \
      -Dcpu=baseline \
      --release=safe

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp zig-out/bin/wmgifdock $out/bin/

    runHook postInstall
  '';

  meta = {
    description = "GIF dock app for Window Maker";
    homepage = "https://github.com/soundhearddev/wmgifdock";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "wmgifdock";
  };
}

