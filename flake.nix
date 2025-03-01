{
  description = "A Nix-flake-based Elixir development environment with containerization using Docker";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [self.overlays.default];
          };
        });
  in {
    overlays.default = final: prev: rec {
      erlang = final.beam.interpreters.erlang_27;
      pkgs-beam = final.beam.packagesWith erlang;
      elixir = pkgs-beam.elixir_1_17;
    };

    devShells = forEachSupportedSystem ({pkgs}: let
      dockerfileContent = ''
        FROM docker.io/hexpm/elixir:1.17.3-erlang-27.2.2-ubuntu-focal-20241011

        ENV MIX_ENV=prod

        RUN apt-get update -y && \
            apt-get install -y git-core && \
            rm -rf /var/lib/apt/lists/*

        WORKDIR /bot

        COPY mix.exs mix.lock ./

        RUN mix deps.get --only prod && \
            mix deps.compile

        COPY . .

        RUN mix compile

        CMD ["mix", "run", "--no-halt"]

      '';

      # docker-compose content with proper escaping of BOT_TOKEN
      dockerComposeContent = ''
        services:
          vennie:
            build:
              context: .
              dockerfile: Dockerfile
            container_name: vennie-bot
            restart: unless-stopped
            environment:
              - BOT_TOKEN=$${BOT_TOKEN}
            volumes:
              - ./priv/repo:/app/priv/repo
      '';

      setupScript = pkgs.writeShellScriptBin "setup-vennie-container" ''
        #!/usr/bin/env bash
        set -e

        if [ ! -f Dockerfile ]; then
          echo "Creating Dockerfile..."
          cat > Dockerfile << 'EOF'
        ${dockerfileContent}
        EOF
          echo "Dockerfile created."
        fi

        if [ ! -f compose.yaml ]; then
          echo "Creating compose.yaml..."
          cat > compose.yaml << 'EOF'
        ${dockerComposeContent}
        EOF
          echo "compose.yaml created."
        fi

        if [ ! -f .env ]; then
          echo "Creating .env file template..."
          echo "BOT_TOKEN=your_bot_token_here" > .env
          echo "Please update the BOT_TOKEN in the .env file"
        fi

        echo "Container setup complete!"
        echo "Available commands:"
        echo "  vennie-build      - Build the container image"
        echo "  vennie-start      - Start the bot container"
        echo "  vennie-stop       - Stop the bot container"
        echo "  vennie-logs       - Show container logs"
        echo "  vennie-restart    - Restart the container"
        echo "  vennie-rebuild    - Rebuild and restart"
      '';

      vennieBuild = pkgs.writeShellScriptBin "vennie-build" ''
        docker-compose build
      '';

      vennieStart = pkgs.writeShellScriptBin "vennie-start" ''
        docker-compose up -d
      '';

      vennieStop = pkgs.writeShellScriptBin "vennie-stop" ''
        docker-compose down
      '';

      vennieLogs = pkgs.writeShellScriptBin "vennie-logs" ''
        docker-compose logs -f
      '';

      vennieRestart = pkgs.writeShellScriptBin "vennie-restart" ''
        docker-compose restart
      '';

      vennieRebuild = pkgs.writeShellScriptBin "vennie-rebuild" ''
        docker-compose up -d --build
      '';
    in {
      default = pkgs.mkShell {
        packages = with pkgs;
          [
            elixir
            ffmpeg
            yt-dlp
            git
            aria2
            nodejs_20
            docker-compose
            docker
            setupScript
            vennieBuild
            vennieStart
            vennieStop
            vennieLogs
            vennieRestart
            vennieRebuild
            sqlite
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            gigalixir
            inotify-tools
            libnotify
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            terminal-notifier
            darwin.apple_sdk.frameworks.CoreFoundation
            darwin.apple_sdk.frameworks.CoreServices
          ];
        shellHook = ''
          echo "Vennie Discord bot development environment using Docker"
          echo ""
          echo "First run: setup-vennie-container"
          echo ""
          echo "Container commands:"
          echo "- vennie-build     : Build the container image"
          echo "- vennie-start     : Start the bot container"
          echo "- vennie-stop      : Stop the bot container"
          echo "- vennie-logs      : Show container logs"
          echo "- vennie-restart   : Restart the container"
          echo "- vennie-rebuild   : Rebuild and restart"
          echo ""
          if [ ! -f Dockerfile ] || [ ! -f compose.yaml ]; then
            echo "Run setup-vennie-container to generate the Docker files"
          fi
        '';
      };
    });
  };
}
