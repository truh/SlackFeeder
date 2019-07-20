
## Developing SlackFeeder on NixOS

Update dependencies:

    pypi2nix -V 3 -e aiohttp -e slacker -e toml

Build Python environment:

    nix-build requirements.nix -A interpreter
