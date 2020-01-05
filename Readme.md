## Configuration

SlackFeeder is configured with a toml file. The default location is
`/etc/slackfeeder.toml` but can be changed with the `SLACKFEEDER_CONFIG`
env variable.

```toml
[Slack]
token = ""

[Feed]
title = ""
id = ""
link.href = ""
link.rel = "self"
description = ""

[Auth]
enabled = true
htpasswd = ""

[Network]
host = "localhost"
port = 8080
```

### Slack

Create a new Slack app here https://api.slack.com/apps?new_app=1. Grant the
permission `im:history`, `im:read`, `users.profile:read`. Put the Slack OAuth
access token in `Slack.token`.

### Feed

A couple of fields used in the generated RSS and ATOM documents.

- `Feed.title`: is the title that will be shown in news readers.
- `Feed.id`: should just be a unique string.
- `Feed.link.href`: the URL of the SlackFeeder app.
- `Feed.link.rel`: `self`
- `Feed.description`

### Auth

If auth is enabled, the option `Auth.htpasswd` must contain a bcrypt hash created
by `htpasswd`.

    $ htpasswd -B -C 10 -n <sername>
    New password: <type password>
    Re-type new password: <type password>
    <password hash>

## Developing SlackFeeder on NixOS

Update dependencies:

    $ pypi2nix -V 3 \
          -e aiohttp \
          -e https://github.com/romis2012/aiohttp-basicauth/archive/0.1.2.tar.gz#egg=aiohttp-basicauth \
          -e slacker \
          -e toml

Build Python environment:

    $ nix-build requirements.nix -A interpreter
    
## NixOS Deployment

* Add nix-channel: `sudo nix-channel --add https://github.com/truh/SlackFeeder/archive/master.tar.gz slackfeeder`

* NixOS sample configuration:

```nix
{
    imports = [
        <slackfeeder/module.nix>
    ];
    
    services.slackfeeder = {
        enable = true;
        Slack = {
            token = "";
        };
        Feed = {
            title = "";
            id = "";
            link.href = "http://localhost:8080/";
            description = "";
        };
        Auth = {
            enable = true;
            htpasswd = "";
        };
        Network = {
            host = "localhost";
            port = 8080;
        };
    };
}
```
