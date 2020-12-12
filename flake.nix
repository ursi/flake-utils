{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: rec {
    builders.simple-js = {
      name,
      version,
      nixpkgs,
      path,
      systems ? flake-utils.lib.defaultSystems,
    }:
      flake-utils.lib.eachSystem systems
        (system:
          with nixpkgs.legacyPackages.${system};

          {
            defaultPackage = stdenv.mkDerivation {
                inherit path;
                pname = name;
                version = version;
                buildInputs = [ nodejs ];
                dontUnpack = true;

                installPhase = ''
                  mkdir -p $out/bin
                  local ex=$out/bin/${name}
                  cp $path $ex
                  chmod +x $ex
                '';
              };
          }
        );

    lib.attrsByPaths = paths: set:
      let
        getPath = set: path:
          with nixpkgs.lib;
          attrByPath
            (splitString "." path)
            (throw "attribute does not exist: ${path}")
            set;
      in
        map (getPath set) paths;

    mkFlakePackages = system: inputs: _: _:
        {
          flakePackages =
            map
              (name: inputs.${name}.defaultPackage.${system})
              (builtins.attrNames inputs);
        };

    mkShell = shellFromNixpkgs: nixpkgs:
      flake-utils.lib.eachDefaultSystem
        (system:
          {
            devShell = shellFromNixpkgs nixpkgs.legacyPackages.${system};
          }
        );

    simpleShell = buildInputs:
      mkShell
        (nixpkgs:
          nixpkgs.mkShell {
            buildInputs = lib.attrsByPaths buildInputs nixpkgs;
          }
        );
  };
}
