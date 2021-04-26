# flake-utils

The goal of this project is to make flakes as nice to use as they can be. It's main use currently is the function documented below, but there are others which you can check out in the source code if you like.

This project has numbered branches which you can use in your flake URLs, the number will be bumped up whenever there is a breaking change, so you should aways be safe to upgrade if you don't change that number.

## default-systems

`default-systems` takes in two arguments:

- a function that takes

  ```
  { make-shell # https://github.com/ursi/nix-make-shell
  , pkgs
  , system
  , ...
  }
  ```

  and returns a set with the standard flake attributes, minus the `system` sub-attributes

- A set: `{ inputs ? null, nixpkgs }`\
  If `inputs` is passed in, `default-systems` will go through all the inputs and check the following (in order)
    - Is it a functor that takes a `system` argument? And do all of the other arguments it takes (other than `pkgs`) have defaults?
    - Does it have a `defaultPackage`?
    - Does it have `packages`?

  If any of these are true, `system` is applied appropriately (and potentailly `pkgs` in the case of a functor) and the result is passed to the function, passed as the first argument to `default-systems` (the one in the previous bullet point). For an input that is being used for `packages`, the set passed the function will be the set of packages, not a set with a `packages` attribute.


### Example

```nix
{ inputs =
    { functor-dep.url = "...";
      default-package-dep.url = "...";
      packages-dep.url = "...";
    };

  outputs = { nixpkgs, utils, ... }@inputs:
    utils.default-systems
      ({ make-shell
       , pkgs
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
                   ];

                 setup = ''echo "Hello, World!"'';
               };
         }
      )
      { inherit inputs nixpkgs; };
}
```
