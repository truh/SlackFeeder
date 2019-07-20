{ pkgs, python }:

self: super: {
  feedgen = pkgs.python3Packages.feedgen;
}