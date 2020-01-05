{ pkgs, python }:

self: super: {
  feedgen = pkgs.python3Packages.feedgen;
  bcrypt = pkgs.python3Packages.bcrypt;
}
