# WMGifDock

A high-performance rewrite of **WMGifDock** (originally a fork of `wmimagedock`) in **Zig**.

https://github.com/user-attachments/assets/38255974-24b3-40ef-b956-be42adff91d5


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
