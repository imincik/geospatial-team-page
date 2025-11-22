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
          entr
          jq
          live-server

          elmPackages.elm
        ];
        shellHook = ''
          function dev-help {
            echo -e "\nWelcome to development environment !"
            echo
            echo "Re-generate packages file:"
            echo "  nix eval --json -f team-packages.nix packages > src/packages.json"
            echo
            echo "Launch live server:"
            echo "  live-server --host=127.0.0.1 --open=index.html src/ & echo \$! > live-server.pid"
            echo
            echo "Re-build main app on change:"
            echo "  find src/ -name "*.elm" | entr -rn elm make src/Main.elm --output=src/main.js"
            echo
            echo "Run 'dev-help' to see this message again."
          }

          function cleanup {
            echo "Stopping live-server ..."
            kill -9 $(cat live-server.pid) || echo ".. failed to stop live-server"
            rm -f live-server.pid
          }

          trap cleanup EXIT

          dev-help
        '';
      };
    };
}
