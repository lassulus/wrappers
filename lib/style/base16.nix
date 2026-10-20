{ lib }:
let
  slots = map (char: "base0${char}") (lib.stringToCharacters "0123456789ABCDEF");

  # Matches `base0A: "#fabd2f" # yellow`, with the quotes, the `#` prefix and
  # the trailing comment all optional.
  #
  # ponytail: canonical slot spelling only. All 303 schemes in
  # `pkgs.base16-schemes` write `base0A`, never `base0a`; a file that does not
  # is reported as missing that slot. Lower case the match if that ever shows
  # up in the wild.
  colorLine = ''[[:space:]]*(base[0-9A-F]{2})[[:space:]]*:[[:space:]]*"?#?([0-9a-fA-F]{6})"?.*'';

  # Matches a top level `variant: "dark"`, tolerating quoting and a trailing comment.
  variantLine = ''[[:space:]]*variant[[:space:]]*:[[:space:]]*"?([^"#]*[^" #])"?.*'';

  /**
    Parse a base16 scheme from the text of a YAML file.

    This is a deliberately small line based parser rather than a real YAML
    parser: it only understands the shape base16 schemes actually take, which
    keeps scheme loading pure. Using a YAML tool would require import from
    derivation, and CI runs `nix flake check`.

    # Type

    ```
    parseScheme :: String -> { palette :: AttrsOf String, variant :: Null | String }
    ```
  */
  parseScheme =
    text:
    let
      lines = lib.splitString "\n" text;
    in
    {
      palette = lib.listToAttrs (
        lib.concatMap (
          line:
          let
            matched = builtins.match colorLine line;
          in
          lib.optional (matched != null) (
            lib.nameValuePair (lib.head matched) (lib.toLower (lib.elemAt matched 1))
          )
        ) lines
      );

      variant = lib.foldl' (
        acc: line:
        let
          matched = builtins.match variantLine line;
        in
        if matched == null then acc else lib.head matched
      ) null lines;
    };

  /**
    Resolve the value of `styling.scheme` into a parsed scheme.

    Accepts a path or derivation holding a base16 YAML file, a string
    containing `/`, treated as a path to one, or any other string, treated as
    a scheme name in `pkgs.base16-schemes`, e.g. `"gruvbox-dark-hard"`.

    Individual colours are set through `styling.palette.<slot>`, which
    overrides the scheme, so there is no attrset form here.

    # Type

    ```
    resolveScheme :: Pkgs -> (Path | Derivation | String) -> { palette; variant; }
    ```
  */
  resolveScheme =
    pkgs: scheme:
    let
      file =
        if lib.isPath scheme || lib.isDerivation scheme || lib.hasInfix "/" scheme then
          scheme
        else
          "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";

      parsed = parseScheme (builtins.readFile file);
      missing = lib.filter (slot: !(parsed.palette ? ${slot})) slots;
    in
    if missing == [ ] then
      parsed
    else
      throw "styling: scheme ${toString scheme} is missing base16 colours: ${lib.concatStringsSep ", " missing}";
in
{
  inherit
    slots
    parseScheme
    resolveScheme
    ;
}
