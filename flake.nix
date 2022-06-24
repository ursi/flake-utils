{ inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { flake-utils, ... }:
    with builtins;
    rec
    { default-systems = flake-utils.lib.defaultSystems;

      apply-systems =
        { inputs
        , make-pkgs ? (system: import inputs.nixpkgs { inherit overlays system; })
        , overlays ? []
        , systems ? default-systems
        }:
        make-outputs:
        flake-utils.lib.eachSystem systems
          (system:
             let
               l = pkgs.lib;
               pkgs = make-pkgs system;
             in
             make-outputs
               ({ inherit pkgs system; }
                // (let
                      filterHelper = v:
                        # since we're inspecting the values to see whether or not they pass the filter, we wrap them in a lambda to keep the lazy evaluation
                        if v?__functor then
                          let
                            arg-names = l.functionArgs v;

                            test-arg = l.flip elem (attrNames arg-names);

                            args-check =
                              l.pipe arg-names
                                [ (l.flip removeAttrs [ "lib" "pkgs" "system" ])
                                  (l.filterAttrs (_: v: !v))
                                  attrNames
                                  (a: length a == 0)
                                ];

                            args =
                              let
                                add-missing = name: value:
                                  if elem name (attrNames arg-names)
                                     && (name == "system" || !arg-names.${name})
                                  then a: a // { ${name} = value; }
                                  else l.id;
                              in
                              if args-check then
                                l.pipe {}
                                  [ (add-missing "lib" l)
                                    (add-missing "pkgs" pkgs)
                                    (add-missing "system" system)
                                  ]
                              else
                                null;
                          in
                          _: v args
                        else if v?defaultPackage then
                          _: v.defaultPackage.${system}
                        else if v?packages then
                          _: if v.packages.${system}?default
                             then v.packages.${system}.default
                             else v.packages.${system}
                        else if v?legacyPackages then
                          _: v.legacyPackages.${system}
                        else
                          null;
                    in
                    l.pipe (removeAttrs inputs [ "self" ])
                      [ (l.filterAttrs (_: v: !isNull (filterHelper v)))
                        (l.mapAttrs (_: v: filterHelper v null))
                      ]
                   )
               )
          );

      lib = l:
        { /*  Returns an array of attributes based off path strings

              Example:
                attrsByPaths [ "a" "b" "c.d"] x
                => [ x.a x.b x.c.d ]
                attrsByPaths [ "a" "b" "c.d"] { a = 1; b = 2; }
                => throws
          */
          attrs-by-paths = paths: set:
            let
              getPath = set: path:
                l.attrByPath
                  (l.splitString "." path)
                  (throw "attribute does not exist: ${path}")
                  set;
            in
            map (getPath set) paths;
        };

      default-packages = system: inputs:
        map
          (name: inputs.${name}.defaultPackage.${system})
          (attrNames inputs);
    };
}
