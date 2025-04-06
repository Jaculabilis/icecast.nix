{
  pkgs ? import <nixpkgs> { },
  ...
}:

let
  audio = pkgs.fetchurl {
    url = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Monkeys%20Spinning%20Monkeys.mp3";
    hash = "sha256-pbs0XCOEmtB4aqC8UVep8tQDlmD+ACguVXVNR1823BQ=";
  };
in
pkgs.writeScriptBin "demo-source" ''
  #!${pkgs.liquidsoap}/bin/liquidsoap

  output.icecast(
    %mp3,
    host="127.0.0.1",
    port=8000,
    password="unguessable",
    mount="demo.mp3",
    description="A demo source",
    single("${audio}"))
''
