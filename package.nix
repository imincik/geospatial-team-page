{
  stdenv,
  elmPackages,
}:

stdenv.mkDerivation {
  # FIXME: avoid building with disabled sandbox
  # nix build .#forge-config --option sandbox relaxed --builders ""
  __noChroot = true;

  pname = "web";
  version = "0.1.0";

  src = ./.;

  buildInputs = [
    elmPackages.elm
  ];

  buildPhase = ''
    export HOME=$(mktemp -d)
    mkdir build

    elm make src/Main.elm --optimize --output=build/main.js
  '';

  installPhase = ''
    mkdir $out

    cp src/index.html $out
    cp build/main.js $out

    # cp -a src/resources $out
  '';
}
