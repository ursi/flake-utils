{
  outputs = _: {
    makeFlakePackages = system: inputs: self: super:
      let
        fold = pkgs: name:
          pkgs ++ [ inputs.${name}.defaultPackage.${system} ];

        flakePackages = builtins.foldl' fold [] (builtins.attrNames inputs);
      in
        { inherit flakePackages; };
    };
}
