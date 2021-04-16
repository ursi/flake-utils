{ inputs =
    { flake-utils.url = "github:numtide/flake-utils";
      make-shell.url = "github:ursi/nix-make-shell";
    };

  outputs = { flake-utils, make-shell, ... }:
    rec
    { /* Make an outputs object out of a lambda of type `{ make-shell, pkgs, system } -> set`

         Example:
           { outputs = { nixpkgs, utils, ... }:
               utils.defaultSystems
                 ({ make-shell, pkgs, ... }:
                    { devShell =
                        make-shell
                          { packages = with pkgs; [ a b c.d ];
                            shellHook = ''echo "Hello, World!"'';
                          };
                    }
                 )
                 nixpkgs
           }
      */
      defaultSystems = mkOutputs: nixpkgs:
        flake-utils.lib.eachDefaultSystem
          (system:
             let pkgs = nixpkgs.legacyPackages.${system}; in
             mkOutputs
               { make-shell =  make-shell { inherit pkgs system; };
                 inherit pkgs system;
               }
          );

      /*  Returns an array of attributes based off path strings

          Example:
            attrsByPaths [ "a" "b" "c.d"] x
            => [ x.a x.b x.c.d ]
            attrsByPaths [ "a" "b" "c.d"] { a = 1; b = 2; }
            => throws
      */
      lib = l:
        { attrsByPaths = paths: set:
            let
              getPath = set: path:
                l.attrByPath
                  (l.splitString "." path)
                  (throw "attribute does not exist: ${path}")
                  set;
            in
            map (getPath set) paths;
        };

      defaultPackages = system: inputs:
        map
          (name: inputs.${name}.defaultPackage.${system})
          (builtins.attrNames inputs);

      /* Make a nix shell out of a lambda of type `{ pkgs, system } -> set`

         Example:
           {
             outputs = { nixpkgs, utils, ... }:
               utils.mkShell
                 ({ pkgs, ... }:
                    with pkgs;
                    { buildInputs = [ a b c.d ];
                      shellHook = ''echo "Hello, World!"'';
                    }
                 )
                 nixpkgs

           }
      */
      mkShell = mkShell':
        defaultSystems
          ({ pkgs, ... }@args: { devShell = pkgs.mkShell (mkShell' args); });

      /* Make a nix shell with the package names in a list

         Example:
           { outputs = { nixpkgs, utils, ... }:
               utils.simpleShell [ "a" "b" "c.d"] nixpkgs;
           }
      */
      simpleShell = buildInputs:
        mkShell ({ pkgs, ... }: { buildInputs = (lib pkgs.lib).attrsByPaths buildInputs pkgs; });
    };
}
