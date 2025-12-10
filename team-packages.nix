# List packages maintained by a person.

# USAGE:
# nix eval --json -f team-packages.nix packages

{
  pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz") {
    config.allowBroken = true;
    config.allowUnfree = true;
  },

  pkgsUnstable ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
    config.allowBroken = true;
    config.allowUnfree = true;
  },

  pkgsStable ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-25.11.tar.gz") {
    config.allowBroken = true;
    config.allowUnfree = true;
  },

  team ? "geospatial",

  showBroken ? true, # show broken packages
}:

let
  inherit (pkgs.lib.debug) traceVal;
  inherit (pkgs.lib)
    attrByPath
    collect
    elem
    filterAttrsRecursive
    flatten
    isAttrs
    isDerivation
    listToAttrs
    map
    mapAttrs
    splitString
    ;

  myTeam = pkgs.lib.teams.${team};

  isMaintainedBy =
    pkg:
    elem myTeam (
      pkg.meta.teams or [ ] ++ (flatten (map (x: x.members or [ ]) (pkg.meta.teams or [ ])))
    );

  isDerivationRobust =
    pkg:
    let
      result = builtins.tryEval (isDerivation pkg);
    in
    if result.success then result.value else false;

  brokenFilter =
    pkg:
    let
      isBroken = pkg.meta.broken;
    in
    if showBroken then
      true
    else if isBroken == false then
      true
    else
      false;

  isPkgSet =
    pkg:
    let
      result = builtins.tryEval ((isAttrs pkg) && (pkg.recurseForDerivations or false));
    in
    if result.success then result.value else false;

  # Lookup a package by path in an alternate package set
  # Example: lookupPackage "python313Packages.shapely" pkgsUnstable
  lookupPackage =
    pkgPath: altPkgs:
    let
      pathParts = splitString "." pkgPath;
      result = builtins.tryEval (attrByPath pathParts null altPkgs);
    in
    if result.success then result.value else null;

  extractLicense =
    license:
    if license == null then
      ""
    else if builtins.isString license then
      license
    else if builtins.isList license then
      builtins.concatStringsSep ", " (map extractLicense license)
    else if builtins.isAttrs license then
      license.spdxId or license.shortName or license.fullName or ""
    else
      "";

  extractMetadata =
    pkg: pkgUnstable: pkgStable:
    let
      meta = pkg.meta or { };
      position = meta.position or "";
      fullPath = if position != "" then (builtins.unsafeDiscardStringContext position) else "";

      # Remove /nix/store/<hash>/ prefix and line number from path using regex
      cleanPath =
        if fullPath != "" then
          let
            # Match /nix/store/<hash>/path/to/file.nix:123 -> path/to/file.nix
            matched = builtins.match "/nix/store/[^/]+/([^:]+):?.*" fullPath;
          in
          if matched != null then builtins.head matched else fullPath
        else
          "";

      pkgVersion = pkg.version or "unknown";
    in
    {
      version = pkgVersion;
      broken = meta.broken or false;
      description = meta.description or "";
      license = extractLicense (meta.license or null);
      homepage = meta.homepage or "";
      recipe = cleanPath;
      versions = {
        master = pkgVersion;
        unstable = if pkgUnstable != null then (pkgUnstable.version or "") else "";
        stable = if pkgStable != null then (pkgStable.version or "") else "";
      };
    };

  recursePackageSet =
    pkgSetName: pkgs:
    mapAttrs (
      name: pkg:
      if isDerivationRobust pkg then
        if isMaintainedBy pkg && brokenFilter pkg then
          let
            pkgPath = if pkgSetName != null then pkgSetName + "." + name else name;
            pkgUnstable = lookupPackage pkgPath pkgsUnstable;
            pkgStable = lookupPackage pkgPath pkgsStable;
          in
          {
            name = pkgPath;
            data = extractMetadata pkg pkgUnstable pkgStable;
          }
        else
          null
      else if isPkgSet pkg then
        recursePackageSet name pkg
      else
        null
    ) pkgs;

  collectPackages =
    tree:
    let
      filtered = filterAttrsRecursive (n: v: v != null) tree;
      pkgList = collect (x: x ? name && x ? data) filtered;
    in
    listToAttrs (
      map (pkg: {
        name = pkg.name;
        value = pkg.data;
      }) pkgList
    );

in
{
  packages = collectPackages (recursePackageSet null pkgs);
}
