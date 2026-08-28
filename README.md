# WMGifDock

A high-performance rewrite of **WMGifDock** (originally a fork of `wmimagedock`) written in **Zig**.

<video src="./example.mp4" controls></video>

## Requirements

* **Zig** (0.16.0)
* `pkg-config`
* `libX11`
* `libXext`
* `imlib2`

## Build

### 1. Via Nix

```sh
nix build # (binary is placed in ./result/bin/wmgifdock)

nix develop # Enter the development environment
```

### 2. Build From Source

```sh
zig build -Doptimize=ReleaseSafe 
# (binary is placed in ./zig-out/bin/wmgifdock)
```
