# GX52 for NixOS

This repository provides a Nix flake for installing [GX52](https://gitlab.com/leinardi/gx52) on NixOS systems. GX52 is a GTK application designed to provide control for the LEDs and MFD of Logitech X52 and X52 Pro H.O.T.A.S. devices.

## Features

- Automatically fetches the latest source from the official repository
- Includes all required dependencies (GTK3, libusb, Python packages, etc.)
- Provides udev rules for device access
- Can be installed system-wide or used temporarily

## Installation Methods

### 1. NixOS Flake Configuration

For NixOS systems using flakes, add this to your `flake.nix`:

```nix
{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gx52.url = "github:Michael-K-Williams/gx52Nix";
  };

  outputs = { self, nixpkgs, gx52, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the GX52 module
        gx52.nixosModules.default
        
        # Your configuration
        {
          programs.gx52 = {
            enable = true;
            addUdevRules = true;  # Allows non-root USB device access
          };
        }
      ];
    };
  };
}
```

Alternatively, you can install just the package without the module:

```nix
{
  environment.systemPackages = [ 
    gx52.packages.x86_64-linux.default 
  ];
  
  # Optional: Add udev rules manually
  services.udev.packages = [ 
    gx52.packages.x86_64-linux.default 
  ];
}
```

Then rebuild your system:
```bash
sudo nixos-rebuild switch --flake
```

### 2. Traditional NixOS Configuration

For non-flake NixOS systems, add this to your `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:
let
  gx52 = builtins.getFlake "github:Michael-K-Williams/gx52Nix";
in
{
  environment.systemPackages = [ 
    gx52.packages.${pkgs.system}.default 
  ];
  
  # Add udev rules
  services.udev.packages = [ 
    gx52.packages.${pkgs.system}.default 
  ];
}
```

### 3. Home Manager Installation

#### With Flakes
Add to your Home Manager flake configuration:

```nix
{
  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    gx52.url = "github:Michael-K-Williams/gx52Nix";
  };

  outputs = { nixpkgs, home-manager, gx52, ... }: {
    homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.packages = [ 
            gx52.packages.x86_64-linux.default 
          ];
        }
      ];
    };
  };
}
```

#### Without Flakes
Add to your Home Manager configuration:

```nix
{ config, pkgs, ... }:
let
  gx52 = builtins.getFlake "github:Michael-K-Williams/gx52Nix";
in
{
  home.packages = [ gx52.packages.${pkgs.system}.default ];
}
```

### 4. Temporary Usage

Run without installing:
```bash
nix run github:Michael-K-Williams/gx52Nix
```

### 5. Development Shell

For development or temporary testing:
```bash
nix develop github:Michael-K-Williams/gx52Nix
```

## Building from Source

Clone and build locally:
```bash
git clone https://github.com/Michael-K-Williams/gx52Nix.git
cd gx52Nix
nix build
```

## USB Device Access

The application needs access to X52 USB devices. The flake includes udev rules that allow non-root access to:
- X52 Pro (06a3:0762)
- X52 (06a3:0255) 
- X52 Pro MFD (06a3:075c)

### Required Setup

**IMPORTANT:** Your user must be in the `plugdev` group for USB device access to work.

#### NixOS Configuration
Add `"plugdev"` to your user's groups in your NixOS configuration:

```nix
users.users.yourusername = {
  extraGroups = [ "wheel" "networkmanager" "plugdev" ];
};
```

After rebuilding, **log out and log back in** (or reboot) for the group changes to take effect.

#### Manual Setup (Non-NixOS)
```bash
sudo usermod -a -G plugdev $USER
# Then log out and log back in
```

### Verification
Check that you're in the plugdev group:
```bash
groups  # Should include "plugdev"
```

If using the NixOS module with `addUdevRules = true`, the udev rules are automatically installed.

## Command Line Options

```bash
gx52 --version              # Show version
gx52 --debug                # Show debug messages  
gx52 --hide-window          # Start with main window hidden
gx52 --add-udev-rule        # Add udev rules (requires root)
gx52 --remove-udev-rule     # Remove udev rules (requires root)
```

## Configuration

Settings and profiles are stored in:
- `$XDG_CONFIG_HOME/gx52` (usually `$HOME/.config/gx52`)

## Updating

The flake automatically fetches from the upstream repository. To update to the latest version:

```bash
nix flake update
# Then rebuild your system or home-manager configuration
```

## Troubleshooting

### Permission Denied Errors
Ensure udev rules are installed and you're in the `plugdev` group:
```bash
groups  # Check if plugdev is listed
sudo gx52 --add-udev-rule  # Add rules if not using NixOS module
```

### Python/GTK Errors
The flake includes all required dependencies. If you encounter import errors, try:
```bash
nix run github:Michael-K-Williams/gx52Nix -- --debug
```

## Development

For local development:
```bash
nix develop
# Now you have all build tools and dependencies available
meson setup build --prefix=/tmp/gx52-install
ninja -C build
ninja -C build install
```

## License

This packaging follows the same GPL-3.0+ license as the original GX52 project.

## Links

- [Original GX52 Project](https://gitlab.com/leinardi/gx52)
- [Upstream Repository](https://github.com/leinardi/gx52)
- [Flathub Package](https://flathub.org/apps/details/com.leinardi.gx52)