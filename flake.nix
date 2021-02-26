{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: rec {
    builders =
      { writeJsScriptBin =
          { name
          , js
          , system ? "x86_64-linux"
          , pkgs ? nixpkgs.legacyPackages.${system}
          , node ? pkgs.nodejs
          }:
            let
            in
              pkgs.stdenv.mkDerivation
                { inherit name;
                  dontUnpack = true;
                  jsBin = pkgs.writeScript "${name}.js" ("#! ${node}/bin/node\n" + js);
                  buildInputs = [ node pkgs.makeWrapper ];
                  installPhase = "mkdir -p $out/bin; ln -s $jsBin $out/bin/$name";
                };

        simple-js = {
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
      };

    /* Make an outputs object out of a lambda of type `{ pkgs, system } -> set`

       Example:
         {
           outputs = { self, nixpkgs, utils }:
             utils.defaultSystems
               ({ pkgs, ... }: with pkgs;
                 {
                   devShell = mkShell {
                     buildInputs = [ a b c.d ];
                     shellHook = ''echo "Hello, World!"'';
                   };
                 }
               )
               nixpkgs

         }
    */
    defaultSystems = mkOutputs: nixpkgs:
      flake-utils.lib.eachDefaultSystem
        (system: mkOutputs {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit system;
        });

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

    defaultPackages = system: inputs:
      map
        (name: inputs.${name}.defaultPackage.${system})
        (builtins.attrNames inputs);

    /* Make a nix shell out of a lambda of type `{ pkgs, system } -> set`

       Example:
         {
           outputs = { self, nixpkgs, utils }:
             utils.mkShell
               ({ pkgs, ... }: with pkgs;
                 {
                   buildInputs = [ a b c.d ];
                   shellHook = ''echo "Hello, World!"'';
                 }
               )
               nixpkgs

         }
    */
    mkShell = mkShell':
      defaultSystems
        ({ pkgs, ... } @ args:
          {
            devShell = pkgs.mkShell (mkShell' args);
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
      mkShell ({ pkgs, ... }: { buildInputs = lib.attrsByPaths buildInputs pkgs; });
  };
}
