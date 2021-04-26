{ inputs =
    { flake-utils.url = "github:numtide/flake-utils";
      make-shell.url = "github:ursi/nix-make-shell";
    };

  outputs = { flake-utils, make-shell, ... }:
    with builtins;
    rec
    # using `self` (for `self.inputs`) causes an infinite recursion
    { default-systems = make-outputs: { nixpkgs, inputs ? null }:
        flake-utils.lib.eachDefaultSystem
          (system:
             let
               l = pkgs.lib;
               pkgs = nixpkgs.legacyPackages.${system};
             in
             make-outputs
               ({ make-shell =  make-shell { inherit pkgs system; };
                  inherit pkgs system;
                }
                // (if isNull inputs then
                      {}
                    else
                      let
                        filterMap = _: v:
                          # since we're inspecting the values to see whether or not they pass the filter, we wrap them in a lambda to keep the lazy evaluation
                          if v?__functor then
                            let
                              args = functionArgs (v.__functor null);

                              test-arg = l.flip elem (attrNames args);

                              args-check =
                                l.pipe args
                                  [ (l.flip removeAttrs [ "pkgs" "system" ])
                                    (l.filterAttrs (_: v: !v))
                                    attrNames
                                    (a: length a == 0)
                                  ];
                            in
                            if test-arg "system" && args-check then
                              if test-arg "pkgs" && !args.pkgs then
                                _: v { inherit pkgs system; }
                              else
                                _: v { inherit system; }
                            else
                              null
                          else if v?defaultPackage then
                            _: v.defaultPackage.${system}
                          else if v?packages then
                            _: v.packages.${system}
                          else
                            null;
                      in
                      l.pipe (removeAttrs inputs [ "self" ])
                        [ (l.filterAttrs (n: v: !isNull (filterMap n v)))
                          (l.mapAttrs (n: v: filterMap n v null))
                        ]
                   )
               )
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
          (attrNames inputs);

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
