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
| Option          | Description                                                        |
| --------------- | ------------------------------------------------------------------ |
| `-e <gif_file>` | Path to the GIF file                                               |
| `-t <speed>`    | Animation speed (`0.5` = 2× faster, `1` = normal, `2` = 2× slower) |
| `-s <size>`     | Window size in pixels (`16–256`, default: `64`)                    |
| `-h`            | Display help                                                       |

### example:
``` sh
wmgifdock -e animation.gif -t 2 -s 96
```