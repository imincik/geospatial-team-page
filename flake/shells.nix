{ inputs, ... }:

{
  perSystem =
    {
      system,
      config,
      pkgs,
      lib,
      ...
    }:

    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          elmPackages.elm
        ];
        shellHook = '''';
      };
    };
}
