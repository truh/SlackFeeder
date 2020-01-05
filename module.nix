{ config, lib, pkgs, ... }:

let

interpreter = (import ./requirements.nix { inherit pkgs; }).interpreter;

slackfeeder_py = ./slackfeeder.py;

in

with lib;
{
    options.services.slackfeeder = {
        enable = mkEnableOption "Enable SlackFeeder service";
        Slack = {
            token = mkOption {
                default = "";
                type = types.str;
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
                type = types.str;
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
        token = "${Slack.token}"

        [Feed]
        title = "${Feed.title}"
        id = "${Feed.id}"
        link.href = "${Feed.link.href}"
        link.rel = "${Feed.link.rel}"
        description = "${Feed.description}"

        ${optionalString Auth.enable ''
        [Auth]
        enable = ${toString Auth.enable}
        htpasswd = "${Auth.htpasswd}"
        ''}

        [Network]
        host = "${Network.host}"
        port = ${toString Network.port}
        '';

        systemd.services.slackfeeder = {
            description = "Feed generated from Slack messages.";
            after = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                ExecStart = "${interpreter}/bin/python ${slackfeeder_py}";
                ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
                User = "slackfeeder";
                Group = "slackfeeder";
            };
        };

        users.users.slackfeeder = {
            createHome = false;
        };
        users.groups.slackfeeder = {
            members = [ "slackfeeder" ];
        };
    };
}
