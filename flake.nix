{
  description = "MetaGPT packaged via uv2nix (multi-arch)";

  inputs = {
    uv2nix.url = "github:pyproject-nix/uv2nix";
    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";
    devshell.url = "github:numtide/devshell";
    # TODO: nvfetcher.url = "github:berberman/nvfetcher/0.7.0";
    flake-utils.url = "github:numtide/flake-utils";
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";

    metagpt.url = "github:geekan/MetaGPT";
    metagpt.flake = false;
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , pyproject-nix
    , uv2nix
    , pyproject-build-systems
    , devshell
    , metagpt
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ devshell.overlays.default ];
      };
      inherit (uv2nix.lib.workspace) loadWorkspace;
      inherit (nixpkgs.lib) composeManyExtensions;
      inherit (pkgs)
        python311
        formats
        writeShellApplication
        runCommand;

      python = python311.withPackages
        (ps: with ps; [
          setuptools
          pip
          wheel
          poetry-core
          hatchling
        ]) // {
        inherit (pkgs.python311)
          stdenv
          version
          pname
          name
          passthru;
      };

      toml = (formats.toml { }).generate "pyproject.toml" {
        project.name = "metagpt";
        project.version = "0.0.1"; # metagpt.shortRev;
        project.description = "The Multi-Agent Framework";
        project.requires-python = "~=3.11.0";
      };

      buildUvWorkspace = writeShellApplication {
        name = "uvlock";
        runtimeInputs = (with pkgs; [ git uv coreutils-full ]);
        text = ''
          mkdir -p "$PRJ_ROOT/src"
          cp --force --no-preserve=mode ${metagpt.outPath}/requirements.txt "$PRJ_ROOT/src"
          cp --force --no-preserve=mode ${toml} "$PRJ_ROOT/src/pyproject.toml"

          cd "$PRJ_ROOT/src"

          uv add -r requirements.txt

          mv "$PRJ_ROOT/src/uv.lock" "$PRJ_ROOT"
          mv "$PRJ_ROOT/src/pyproject.toml" "$PRJ_ROOT"

          cd "$PRJ_ROOT"
          rm -rf "$PRJ_ROOT/src"
          git add .
        '';
      };

      metagptSrc = runCommand "metagpt-src" { } ''
        mkdir -p "$out"
        cp -r ${metagpt.outPath}/* "$out/"
        cp ${self}/pyproject.toml "$out/"
        cp ${self}/uv.lock "$out/"
      '';

      workspace = loadWorkspace { workspaceRoot = metagptSrc; };
      overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
      ps = pkgs.callPackage pyproject-nix.build.packages { inherit python; };
      pythonSet = ps.overrideScope (composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
      ]);

      metagptEnv = pythonSet.mkVirtualEnv "metagpt-env" workspace.deps.default;
    in
    {
      packages.metagpt = pkgs.stdenv.mkDerivation {
        name = "metagpt-git-${metagpt.shortRev}";
        buildInputs = [ metagptEnv ];
        dontUnpack = true;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/bin
          cat > $out/bin/metagpt << EOF
          #!${pkgs.stdenv.shell}
          export PYTHONPATH=${metagptEnv}/lib/python3.11/site-packages:\$PYTHONPATH
          exec ${metagptEnv}/bin/python -m metagpt.software_company "\$@"
          EOF
          chmod +x $out/bin/metagpt
        '';
      };

      apps.metagpt = {
        type = "app";
        program = "${self.packages.${system}.metagpt}/bin/metagpt";
      };

      devShells.default = pkgs.devshell.mkShell {
        name = "metagpt-git-${metagpt.shortRev}";
        # packages = with pkgs; [ nixVersions.stable ];
        commands = [{
          name = buildUvWorkspace.name;
          help = "build python deps";
          package = buildUvWorkspace;
        }];
      };
    }
    );
}
