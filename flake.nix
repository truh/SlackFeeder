{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # see https://github.com/nix-community/poetry2nix/tree/master#api for more functions and examples.
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication mkPoetryEnv defaultPoetryOverrides overrides;
      in
      {
        packages = {
          slackfeeder = mkPoetryApplication {
	    projectDir = self;
            overrides = overrides.withDefaults (self: super: {
              slacker = super.slacker.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or []) ++ [super.setuptools];
              });
	      aiohttp-basicauth = super.aiohttp-basicauth.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or []) ++ [super.setuptools];
              });
            });
	  };
          default = self.packages.${system}.slackfeeder;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.slackfeeder ];
          packages = [ pkgs.poetry ];
        };
      });
}

