{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  name = "wmgifdock-dev";
  
  buildInputs = with pkgs; [
    gcc
    gnumake
    pkg-config
    
    # X11
    xorg.libX11
    xorg.libXext
    xorg.libXpm
    
    # Image processing
    imlib2
    imagemagick
    
    # Boost
    boost
  ];
  
  shellHook = ''
    echo "=== wmgifdock development environment ==="
    echo "Run: make clean && make"
    echo "Then: ./wmgifdock -e <gif_file>"
  '';
}
