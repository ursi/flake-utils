# flake-utils

The goal of this project is to make flakes as nice to use as they can be. It's main use currently is the functions documented below, but there are others which you can check out in the source code if you like.

This project has numbered branches which you can use in your flake URLs, the number will be bumped up whenever there is a breaking change, so you should be safe to upgrade if you don't change that number.

## make-flake

`make-flake` takes two arguments:

- An attribute set that satisfies this parameter
  ```
  { inputs
  , make-pkgs ? (system: import inputs.nixpkgs { inherit overlays system; })
  , overlays ? []
  , systems ? default-systems
  }
  ```
- A function that takes

  ```
  { pkgs
  , system
  , ...
  }
  ```

### The `input` option

Every attribute set in `inputs` will be checked for the following things in order:

- Does it have a `defaultPackage`?
- Does it have `packages`?
- Does it have `legacyPackages`?
- Is it a functor that takes some combination of `lib`, `pkgs`, and `system` arguments? And do all of the other arguments it takes (if any) have defaults?

If any of these are true, `system` is applied appropriately (and potentially `lib` or `pkgs` in the case of a functor) and the result is passed to the function which was passed as the second argument to `make-flake`. For an input that is being used for `packages`/`legacyPackages`, the attribute set passed to the function will be the set of packages, not a set with a `packages`/`legacyPackages` attribute.

### Example

```nix
{ inputs =
    { nixpkgs.url = "...";
      functor-dep.url = "...";
      default-package-dep.url = "...";
      overlay-dep.url = "...";
      packages-dep.url = "...";
      pkgs-old.url = "github:NixOS/nixpkgs/...";
      utils.url = "github:ursi/flake-utils/<version>";
    };

  outputs = { overlay-dep, utils, ... }@inputs:
    utils.make-flake
      { inherit inputs;
        overlays = [ overlay-dep.overlay ];
      }
      ({ pkgs
       , pkgs-old
       , functor-dep
       , default-package-dep
       , packages-dep
       , ...
       }:
         { defaultPackage = functor-dep { config = { executable-name = "example"; }; };

           devShell =
             pkgs.mkShell
               { buildInputs =
                   with pkgs;
                   [ defalut-package-dep
                     package-from-overlay
                     packages-dep.package1
                     packages-dep.package2
                     pkgs-old.package3
                   ];

                 shellHook = ''echo "Hello, World!"'';
               };
         }
      );
}
```
