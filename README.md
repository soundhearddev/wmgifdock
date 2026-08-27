# WMGifDock

This is a fork of wmimagedock.

## Build
Requirements: `pkgconf` `libx11` `libxext` `libxpm` `imlib2` `imagemagick` `boost`

For Legacy Distros:

``` sh
make
```

Nix:

``` sh
nix build      # output: ./result/bin/wmgifdock

# optionally:
nix develop # for development environment
```

## Usage

``` sh
wmgifdock
```