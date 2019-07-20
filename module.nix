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
                type = types.string;
                description = "Slack OAuth access token";
            };
        };
        Feed = {
            title = mkOption {
                default = "SlackFeeder";
                type = types.string;
            };
            id = mkOption {
                default = "";
                type = types.string;
            };
            link = {
                href = mkOption {
                    default = "";
                    type = types.string;
                };
                rel = mkOption {
                    default = "self";
                    type = types.string;
                };
            };
            description = mkOption {
                default = "Feed generated from Slack messages.";
                type = types.string;
            };
        };
        Auth = {
            enabled = mkOption {
                default = false;
                type = types.bool;
                description = "Enable basic auth";
            };
            htpasswd = mkOption {
                default = "";
                type = types.string;
                description = "Bcrypt password hash";
            };
        };
    };

    config = mkIf config.services.slackfeeder.enable {
        environment.etc."slackfeeder.toml".text = ''
        [Slack]
        token = "${config.services.slackfeeder.Slack.token}"

        [Feed]
        title = "${config.services.slackfeeder.Feed.title}"
        id = "${config.services.slackfeeder.Feed.id}"
        link.href = "${config.services.slackfeeder.Feed.link.href}"
        link.rel = "${config.services.slackfeeder.Feed.link.rel}"
        description = "${config.services.slackfeeder.Feed.description}"

        ${optionalString config.services.slackfeeder.Auth.enabled ''
        [Auth]
        enabled = ${config.services.slackfeeder.Auth.enabled}
        htpasswd = "${config.services.slackfeeder.Auth.htpasswd}"
        ''}
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
