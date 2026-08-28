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
nix develop # Enter the development environment

zig build -Doptimize=ReleaseSafe
```

### 2. Build From Source

```sh
zig build -Doptimize=ReleaseSafe 
# (binary is placed in ./zig-out/bin/wmgifdock)
```
