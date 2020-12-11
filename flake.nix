{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils }: {
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

    makeFlakePackages = system: inputs: self: super:
      let
        fold = pkgs: name:
          pkgs ++ [ inputs.${name}.defaultPackage.${system} ];

        flakePackages = builtins.foldl' fold [] (builtins.attrNames inputs);
      in
        { inherit flakePackages; };
    };
}
