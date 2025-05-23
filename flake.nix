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
    flake-utils.lib.eachDefaultSystem
      (system:
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
          project.readme = ''
            The Multi-Agent Framework: First AI Software Company, Towards Natural Language Programming
          '';
          project.requires-python = "~=3.11.0";
          # project.dynamic = [
          #   "readme"
          #   "license"
          #   "authors"
          #   "keywords"
          #   "scripts"
          #   "optional-dependencies"
          # ];
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

        metagptPackage =
          { buildPythonPackage
          , python311Packages
          , pythonAtLeast
          , pythonOlder
          }:

          buildPythonPackage {
            src = metagptSrc; # metagpt.outPath;
            name = "metagpt";
            version = "git-${metagpt.shortRev}";

            # Use Python 3.11 explicitly
            python = python311;
            pythonPackages = python311Packages;

            disabled = !(pythonAtLeast "3.9" && pythonOlder "3.12");

            # Add build-time tools if needed
            nativeBuildInputs = [ python311Packages.pip ];

            # Expose Python dependencies from requirements.txt
            propagatedBuildInputs = with python311Packages; [
              aiohttp
              channels
              faiss
              fire
              typer
              lancedb
              loguru
              meilisearch
              numpy
              openai
              openpyxl
              beautifulsoup4
              pandas
              pydantic
              python-docx
              pyyaml
              setuptools
              tenacity
              tiktoken
              tqdm
              anthropic
              typing-inspect
              libcst
              qdrant-client
              grpcio
              grpcio-tools
              grpcio-status
              # ta
              # zhipuai
              # semantic-kernel
              # tree-sitter
              # tree-sitter-python

              wrapt
              redis
              curl-cffi
              httplib2
              websocket-client
              aiofiles
              gitpython
              rich
              nbclient
              nbformat
              ipython
              ipykernel
              scikit-learn
              typing-extensions
              socksio
              gitignore-parser
              websockets
              networkx
              google-generativeai
              playwright
              anytree
              ipywidgets
              pillow
              imap-tools
              pylint
              pygithub
              htmlmin
              fsspec
              grep-ast
              unidiff
              qianfan
              dashscope
              rank-bm25
              jieba
              gymnasium
              boto3
              spark-ai-python
              httpx
            ];

            # Optional: disable building on non-Linux
            # meta = with lib; {
            #   description = "MetaGPT: multi-agent framework for natural language programming";
            #   homepage = "https://github.com/FoundationAgents/MetaGPT";
            #   license = licenses.mit;
            #   platforms = stdenv.lib.platforms.linux;
            # };
          };


        metagptPythonPackage = pkgs.python311Packages.callPackage
          ({ buildPythonPackage
           , pythonAtLeast
           , pythonOlder
           , setuptools
           , wheel

           , nodejs
           , pnpm
           }:
            buildPythonPackage {
              src = metagptSrc; # metagpt.outPath;
              name = "metagpt";
              version = "git-${metagpt.shortRev}";

              # format = "setuptools";
              pyproject = false;

              disabled = !(pythonAtLeast "3.9" && pythonOlder "3.12");

              doCheck = false;
              pythonImportsCheck = [ "metagpt" ];

              nativeBuildInputs = [
                setuptools
                wheel
              ];

              propagatedBuildInputs = metagptEnv.buildInputs;

              # postInstall = ''
              #   export HOME=$TMPDIR
              #   pnpm install @mermaid-js/mermaid-cli
              # '';

              # inherit (metagptEnv) buildInputs;

              # installPhase = ''
              #   mkdir -p $out/bin
              #   cat > $out/bin/metagpt << EOF
              #   #!${pkgs.stdenv.shell}
              #   export PYTHONPATH=${metagptEnv}/lib/python3.11/site-packages:\$PYTHONPATH
              #   exec ${metagptEnv}/bin/python -m metagpt.software_company "\$@"
              #   EOF
              #   chmod +x $out/bin/metagpt
              # '';
            })
          { };

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

        packages.tested = pkgs.python311Packages.callPackage metagptPackage { };
        packages.default = self.packages.${system}.metagpt;
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
          commands = [{
            name = buildUvWorkspace.name;
            help = "build python deps";
            package = buildUvWorkspace;
          }];
        };

      }) // {
      hydraJobs = self.packages;
      overlays.default = final: prev: {
        inherit (self.packages.${final.system}) metagpt;
        # metagptPkg = prev.python311Packages.callPackage metagptPackage { };
      };
      homeManagerModules.default = import ./nix/hm-module.nix self;
    };

}
