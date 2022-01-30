{ inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { flake-utils, ... }:
    with builtins;
    rec
    { default-systems = flake-utils.lib.defaultSystems;

      for-default-systems = for-systems default-systems;

      for-systems = systems: make-outputs: inputs:
        for-systems-with-pkgs
          systems
          make-outputs
          (system: inputs.nixpkgs.legacyPackages.${system})
          inputs;

      for-systems-with-pkgs = systems: make-outputs: make-pkgs: inputs:
                                                                # ^ using `self` (for `self.inputs`) causes an infinite recursion
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
                        if v?defaultPackage then
                          _: v.defaultPackage.${system}
                        else if v?packages then
                          _: v.packages.${system}
                        else if v?legacyPackages then
                          _: v.legacyPackages.${system}
                        else if v?__functor then
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
