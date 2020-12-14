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

    defaultSystems = pkgsToOutputs: nixpkgs:
      flake-utils.lib.eachDefaultSystem
        (system: pkgsToOutputs nixpkgs.legacyPackages.${system});

    /*  Returns an array of attributes based off path strings

        Example:
          attrsByPaths [ "a" "b" "c.d"] x
          => [ x.a x.b x.c.d ]
          attrsByPaths [ "a" "b" "c.d"] { a = 1; b = 2; }
          => throws
    */
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

    /* Make a nix shell out of a lambda of type `pkgs -> shell`

       Example:
         {
           outputs = { self, nixpkgs, utils }:
             utils.mkShell
               (pkgs: with pkgs;
                 mkShell {
                   buildInputs = [ a b c.d ];
                   shellHook = ''echo "Hello, World!"''
                 }
               )
               nixpkgs

         }
    */
    mkShell = shellFromPkgs: nixpkgs:
      flake-utils.lib.eachDefaultSystem
        (system:
          {
            devShell = shellFromPkgs nixpkgs.legacyPackages.${system};
          }
        );

    /* Make a nix shell with the package names in a list

       Example:
         {
           outputs = { self, nixpkgs, utils }:
             utils.simpleShell [ "a" "b" "c.d"] nixpkgs;
         }
    */
    simpleShell = buildInputs:
      mkShell
        (pkgs:
          pkgs.mkShell {
            buildInputs = lib.attrsByPaths buildInputs pkgs;
          }
        );
  };
}
