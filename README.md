# flake-utils

The goal of this project is to make flakes as nice to use as they can be. It's main use currently is the function documented below, but there are others which you can check out in the source code if you like.

This project has numbered branches which you can use in your flake URLs, the number will be bumped up whenever there is a breaking change, so you should aways be safe to upgrade if you don't change that number.

## default-systems

`default-systems` is just `for-systems` (defined below) with the list of systems supported by nixpkgs and built by hydra passed as the first argument.

## for-systems

`for-systems` takes in three arguments:

- A list of strings representing which systems to build the flake for
- A function that takes

  ```
  { make-shell # https://github.com/ursi/nix-make-shell
  , pkgs
  , system
  , ...
  }
  ```

  and returns an attribute set with the standard flake attributes, minus the `system` sub-attributes
- An attribute set of inputs that must contain a `nixpkgs` attribute:\
  `for-systems` will go through all the inputs and check the following (in order)
    - Does it have a `defaultPackage`?
    - Does it have `packages`?
    - Does it have `legacyPackages`?
    - Is it a functor that takes a `system` argument? And do all of the other arguments it takes (other than `pkgs`) have defaults?

  If any of these are true, `system` is applied appropriately (and potentially `pkgs` in the case of a functor) and the result is passed to the function which was passed as the second argument to `for-systems` (the one in the previous bullet point). For an input that is being used for `packages`/`legacyPackages`, the attribute set passed to the function will be the set of packages, not a set with a `packages`/`legacyPackages` attribute.


### Example

```nix
{ inputs =
    { nixpkgs.url = "...";
      functor-dep.url = "...";
      default-package-dep.url = "...";
      packages-dep.url = "...";
      pkgs-old.url = "github:NixOS/nixpkgs/...";
    };

  outputs = { utils, ... }@inputs:
    utils.default-systems
      ({ make-shell
       , pkgs
       , pkgs-old
       , functor-dep
       , default-package-dep
       , packages-dep
       , ...
       }:
         { defaultPackage = functor-dep { config = { executable-name = "example"; }; };

           devShell =
             make-shell
               { packages =
                   with pkgs;
                   [ defalut-package-dep
                     packages-dep.package1
                     packages-dep.package2
                     pkgs-old.packag3
                   ];

                 setup = ''echo "Hello, World!"'';
               };
         }
      )
      inputs;
}
```
