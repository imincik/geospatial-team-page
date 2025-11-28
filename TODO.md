# TODOs

* Show unstable and stable versions of a package

* Show list of opened and closed Issues and PRs for a package

* List broken packages

* List packages without package test

* List packages without working update script

* Add package usage instructions

```
  nix shell nixpkgs/nixos-unstable#<package>
```

or more complex

```
  nix shell \
    --impure \
    --expr "with (import (fetchTarball \"https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz\") {}); python3.withPackages (ps: with python3Packages; [ <package> ])"
```
