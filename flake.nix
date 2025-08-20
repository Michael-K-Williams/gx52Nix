{
  description = "GX52 - GTK application for Logitech X52 H.O.T.A.S. control";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Python dependencies that might not be in nixpkgs
        pythonPackages = pkgs.python3Packages;
        
        # Custom injector package since it's not in nixpkgs
        injector = pythonPackages.buildPythonPackage rec {
          pname = "injector";
          version = "0.21.0";
          pyproject = true;
          
          src = pkgs.fetchPypi {
            inherit pname version;
            sha256 = "sha256-kZ62uflvQL+Y/aNMeXYrIXvRVE2a3DWAX/KUjpI1bJw=";
          };
          
          build-system = [ pythonPackages.setuptools ];
          
          doCheck = false;
          meta = with pkgs.lib; {
            description = "Python dependency injection framework";
            homepage = "https://github.com/alecthomas/injector";
            license = licenses.bsd3;
          };
        };

        gx52 = pkgs.python3Packages.buildPythonApplication rec {
          pname = "gx52";
          version = "0.7.6";
          
          src = pkgs.fetchFromGitHub {
            owner = "leinardi";
            repo = "gx52";
            rev = "55100e49d987dd041885ab28f92d9bc83f63aff5";  # Latest commit on release branch
            fetchSubmodules = true;  # Include submodules like python-xlib
            sha256 = "sha256-PfR/Xu2QX3Zgo2JL3/dfGdve1V3nmEZg6sM4iIHR8r4=";
          };
          
          format = "other";
          
          postPatch = ''
            # Remove the post-install script that doesn't work in Nix sandbox
            sed -i "s/meson.add_install_script('scripts\/meson_post_install.py')/# meson.add_install_script('scripts\/meson_post_install.py')/" meson.build
          '';
          
          nativeBuildInputs = with pkgs; [
            meson
            ninja
            pkg-config
            libxml2
            glib
            wrapGAppsHook
            gobject-introspection
          ];
          
          buildInputs = with pkgs; [
            gtk3
            libusb1
            udev
            libappindicator-gtk3
            gsettings-desktop-schemas
            libnotify
          ];
          
          propagatedBuildInputs = with pythonPackages; [
            evdev
            injector
            peewee
            pygobject3
            pyudev
            pyusb
            pyxdg
            requests
            reactivex
            setuptools  # Provides distutils for Python 3.12+
          ];
          
          configurePhase = ''
            runHook preConfigure
            meson setup build --prefix=$out
            runHook postConfigure
          '';
          
          buildPhase = ''
            runHook preBuild
            ninja -C build
            runHook postBuild
          '';
          
          installPhase = ''
            runHook preInstall
            ninja -C build install
            runHook postInstall
          '';
          
          postInstall = ''
            # Ensure the desktop file is properly installed
            mkdir -p $out/share/applications
            
            # Install udev rules
            mkdir -p $out/lib/udev/rules.d
            cat > $out/lib/udev/rules.d/60-gx52.rules << EOF
SUBSYSTEMS=="usb", ATTRS{idVendor}=="06a3", ATTRS{idProduct}=="0762", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="06a3", ATTRS{idProduct}=="0255", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="06a3", ATTRS{idProduct}=="075c", MODE="0666"
EOF
          '';
          
          preFixup = ''
            makeWrapperArgs+=("--prefix" "XDG_DATA_DIRS" ":" "$out/share:$GSETTINGS_SCHEMAS_PATH")
          '';
          
          meta = with pkgs.lib; {
            description = "GTK application for Logitech X52 and X52 Pro H.O.T.A.S. control";
            longDescription = ''
              GX52 is a GTK application designed to provide control for the LEDs and MFD 
              of Logitech X52 and X52 Pro H.O.T.A.S. devices. Features include LED color 
              control, brightness settings, MFD management, and profile saving/restoring.
            '';
            homepage = "https://gitlab.com/leinardi/gx52";
            license = licenses.gpl3Plus;
            maintainers = [ ];
            platforms = platforms.linux;
            mainProgram = "gx52";
          };
        };
      in
      {
        packages = {
          default = gx52;
          gx52 = gx52;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Build dependencies
            python3
            python3Packages.pip
            meson
            ninja
            pkg-config
            libxml2
            
            # System dependencies
            gtk3
            gobject-introspection
            libusb1
            udev
            appstream-glib
            
            # Python packages
            python3Packages.evdev
            injector
            python3Packages.peewee
            python3Packages.pygobject3
            python3Packages.pyudev
            python3Packages.pyusb
            python3Packages.pyxdg
            python3Packages.requests
            python3Packages.reactivex
            
            # Additional runtime dependencies
            libappindicator-gtk3
          ];

          shellHook = ''
            echo "GX52 development environment loaded"
            echo "Available commands:"
            echo "  nix build .#gx52     - Build the package"
            echo "  nix run .#gx52       - Run GX52"
            echo "  nix develop          - Enter development shell"
          '';
        };

        apps.default = flake-utils.lib.mkApp {
          drv = gx52;
          name = "gx52";
        };
      }
    ) // {
      # NixOS module for easy system integration
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.gx52;
        in {
          options.programs.gx52 = {
            enable = mkEnableOption "GX52 Logitech X52 H.O.T.A.S. control application";
            
            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "The GX52 package to use.";
            };
            
            addUdevRules = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to add udev rules for X52 device access.";
            };
          };
          
          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
            
            services.udev.packages = mkIf cfg.addUdevRules [ cfg.package ];
            
            # Ensure required groups exist for USB access
            users.groups.plugdev = {};
          };
        };
      
      # Overlay for adding to nixpkgs
      overlays.default = final: prev: {
        gx52 = self.packages.${prev.system}.default;
      };
    };
}