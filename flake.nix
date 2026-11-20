{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all (system: f system);
    in
    {
      lib = import ./lib { lib = nixpkgs.lib; };
      wrapperModules = import ./modules.nix {
        lib = nixpkgs.lib;
        wlib = self.lib;
      };
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      templates = {
        devenv-postgresql = {
          path = ./templates/devenv-postgresql;
          description = "A template making use of process-compose to create a postgresql dev environment, adding treefmt and flake-parts";
        };
      };
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Load checks from checks/ directory
          checkFiles = builtins.readDir ./checks;
          importCheck = name: {
            name = nixpkgs.lib.removeSuffix ".nix" name;
            value = import (./checks + "/${name}") {
              inherit pkgs;
              self = self;
            };
          };
          checksFromDir = builtins.listToAttrs (
            map importCheck (
              builtins.filter (name: nixpkgs.lib.hasSuffix ".nix" name) (builtins.attrNames checkFiles)
            )
          );

          # Load checks from modules/**/check.nix
          moduleFiles = builtins.readDir ./modules;
          importModuleCheck =
            name: type:
            let
              checkPath = ./modules + "/${name}/check.nix";
              # Check if current system is in the module's supported platforms
              isSupported = builtins.elem system self.wrapperModules.${name}.meta.platforms;
            in
            if type == "directory" && builtins.pathExists checkPath && isSupported then
              {
                name = "module-${name}";
                value = import checkPath {
                  inherit pkgs;
                  self = self;
                };
              }
            else
              null;
          checksFromModules = builtins.listToAttrs (
            nixpkgs.lib.filter (x: x != null) (nixpkgs.lib.mapAttrsToList importModuleCheck moduleFiles)
          );
        in
        checksFromDir // checksFromModules
      );
    };
}
