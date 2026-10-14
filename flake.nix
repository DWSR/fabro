{
  description = "Development environment for Fabro workflows";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Fabro CLI, packaged from the upstream release tarball: upstream
      # ships no flake and the official source build requires a Bun web-UI
      # build step (`cargo dev spa refresh`) that nixpkgs' cargo packaging
      # cannot reproduce. Bumps: update `fabroVersion` and refresh the
      # per-system hashes from the matching `fabro-<triple>.tar.gz.sha256`
      # release assets (musl builds for Linux, so no autoPatchelf).
      fabroVersion = "0.386.0-nightly.0";
      fabroTargets = {
        aarch64-darwin = {
          triple = "aarch64-apple-darwin";
          hash = "sha256-0a2Bx0vvQ2Y4x3kna0IJQn3scN5RaeOK4wyP5ipm2Q0=";
        };
        aarch64-linux = {
          triple = "aarch64-unknown-linux-musl";
          hash = "sha256-quK1W6KyLVCycuvQAy3fwFjtQx8jW685+futij5JLuM=";
        };
        x86_64-linux = {
          triple = "x86_64-unknown-linux-musl";
          hash = "sha256-NGTXeCBpTs+LhsAkwZnY2IlJqhLv5ovcrHCZdQ0r0kY=";
        };
      };
      mkFabro =
        pkgs: target:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "fabro";
          version = fabroVersion;

          src = pkgs.fetchurl {
            url = "https://github.com/fabro-sh/fabro/releases/download/v${fabroVersion}/fabro-${target.triple}.tar.gz";
            inherit (target) hash;
          };

          sourceRoot = "fabro-${target.triple}";

          # Install the upstream binary verbatim. The release build strips
          # itself and the macOS binary is ad-hoc linker-signed — arm64
          # refuses to exec a modified-signature binary, so fixupPhase
          # (which would strip) must never touch its bytes.
          dontConfigure = true;
          dontBuild = true;
          dontFixup = true;

          installPhase = ''
            runHook preInstall

            install -Dm755 fabro "$out/bin/fabro"

            runHook postInstall
          '';

          meta = {
            description = "The open source dark software factory for expert engineers";
            homepage = "https://fabro.sh/";
            license = pkgs.lib.licenses.mit;
            mainProgram = "fabro";
            sourceProvenance = with pkgs.lib.sourceTypes; [ binaryNativeCode ];
            platforms = builtins.attrNames fabroTargets;
          };
        };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = nixpkgs.lib;
        in
        {
          default = pkgs.mkShellNoCC {
            packages =
              with pkgs;
              [
                # Renders `fabro graph` output and DOT graphs to SVG/PNG.
                graphviz

                # Lints workflow prompts (`prompts/*.md`) and other Markdown.
                markdownlint-cli2

                # Lints and formats workflow shell scripts (`script` nodes,
                # `scripts/*.sh`).
                shellcheck
                shfmt
              ]
              # Upstream publishes no x86_64-darwin CLI build; the rest of
              # the toolchain still works there.
              ++ lib.optional (builtins.hasAttr system fabroTargets) (
                mkFabro pkgs fabroTargets.${system}
              );
          };
        }
      );
    };
}
