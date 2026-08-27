# WMGifDock

This is a fork of wmimagedock.

## Build

Classic:

```
make clean && make
```

Nix:

```
nix build      # -> result/bin/wmgifdock
nix develop    # dev shell with all deps
```

## Dependencies

- libX11, libXext, libXpm
- imlib2
- imagemagick
- boost (build only)

## Usage

```
wmgifdock
```