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
        shellHook =
          ''
            function dev-help {
              echo -e "\nWelcome to the development environment !"
              echo
              echo "Re-generate packages file:"
              echo "  nix eval --json -f team-packages.nix packages | jq > src/packages.json"
              echo
              echo "Start the development server:"
              echo "  dev-server"
              echo
              echo "Run 'dev-help' to see this message again."
            }

            function dev-server {
              echo "Starting development server..."
              echo

              # Check if we're in the correct directory
              if [ ! -d "src" ]; then
                echo "Error: src directory not found"
                return 1
              fi

              # Start watcher
              echo "Starting Main.elm watcher..."
              find src/ -name "*.elm" | entr -rn elm make src/Main.elm --output=src/main.js &
              MAIN_WATCHER_PID=$!

              # Start live-server
              echo "Starting live-server..."
              live-server --host=127.0.0.1 --port=8080 --open=/index.html src/ &
              LIVE_SERVER_PID=$!

              echo
              echo "Development server is running!"
              echo "  Live server: http://127.0.0.1:8080/index.html"
              echo
              echo "Press Ctrl+C to stop all watchers and the server."
              echo

              # Trap Ctrl+C to clean up all background jobs
              trap "echo 'Stopping all watchers and live-server...'; kill $LIVE_SERVER_PID $MAIN_WATCHER_PID 2>/dev/null; rm -f live-server.pid; echo 'Stopped.'; return" INT

              # Wait for all background jobs
              wait
            }

            dev-help
          '';
      };
    };
}
