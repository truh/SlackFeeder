{
  description = "Application packaged using poetry2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.systems.follows = "flake-utils/systems";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;}) mkPoetryApplication mkPoetryEnv defaultPoetryOverrides overrides;
    in {
      formatter = pkgs.alejandra;

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

      nixosModules.default = {
        config,
        lib,
        pkgs,
        ...
      }:
        with lib; {
          options.services.slackfeeder = {
            enable = mkEnableOption "Enable SlackFeeder service";
            package = mkOption {
              default = self.packages.${pkgs.system}.slackfeeder;
              type = types.package;
            };
            Slack = {
              token = mkOption {
                default = "";
                type = types.nullOr types.str;
                description = "Slack OAuth access token";
              };
              token_file = mkOption {
                default = "";
                type = types.nullOr types.str;
                description = "Slack OAuth access token";
              };
            };
            Feed = {
              title = mkOption {
                default = "SlackFeeder";
                type = types.str;
              };
              id = mkOption {
                default = "";
                type = types.str;
              };
              link = {
                href = mkOption {
                  default = "";
                  type = types.str;
                };
                rel = mkOption {
                  default = "self";
                  type = types.str;
                };
              };
              description = mkOption {
                default = "Feed generated from Slack messages.";
                type = types.str;
              };
            };
            Auth = {
              enable = mkOption {
                default = false;
                type = types.bool;
                description = "Enable basic auth";
              };
              htpasswd = mkOption {
                default = "";
                type = types.nullOr types.str;
                description = "Bcrypt password hash";
              };
              htpasswd_file = mkOption {
                default = "";
                type = types.nullOr types.str;
                description = "Bcrypt password hash";
              };
            };
            Network = {
              host = mkOption {
                default = "localhost";
                type = types.str;
              };
              port = mkOption {
                default = 8080;
                type = types.int;
              };
            };
          };

          config = mkIf config.services.slackfeeder.enable {
            environment.etc."slackfeeder.toml".text = with config.services.slackfeeder; ''
              [Slack]
              ${optionalString (Slack.token != null) ''token = "${Slack.token}"''}
              ${optionalString (Slack.token_file != null) ''token = "${Slack.token}"''}

              [Feed]
              title = "${Feed.title}"
              id = "${Feed.id}"
              link.href = "${Feed.link.href}"
              link.rel = "${Feed.link.rel}"
              description = "${Feed.description}"

              ${optionalString Auth.enable ''
                [Auth]
                enable = ${toString Auth.enable}
                ${optionalString (Auth.htpasswd != null) ''htpasswd = "${Auth.htpasswd}"''}
                ${optionalString (Auth.htpasswd_file != null) ''htpasswd_file = "${Auth.htpasswd_file}"''}
              ''}

              [Network]
              host = "${Network.host}"
              port = ${toString Network.port}
            '';

            systemd.services.slackfeeder = {
              description = "Feed generated from Slack messages.";
              after = ["network-online.target"];
              wantedBy = ["multi-user.target"];
              path = [config.services.slackfeeder.package];
              script = "slackfeeder";
              serviceConfig = {
                ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
                User = "slackfeeder";
                Group = "slackfeeder";
              };
            };

            users.users.slackfeeder = {
              createHome = false;
              isSystemUser = true;
              group = "slackfeeder";
            };
            users.groups.slackfeeder = {
              members = ["slackfeeder"];
            };
          };
        };

      devShells.default = pkgs.mkShell {
        inputsFrom = [self.packages.${system}.slackfeeder];
        packages = [pkgs.poetry];
      };
    });
}
