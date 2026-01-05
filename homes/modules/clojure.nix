{pkgs, ...}: {
  home.packages = [
    pkgs.babashka
    pkgs.clj-kondo
    pkgs.cljfmt
    pkgs.clojure
    pkgs.clojure-lsp
  ];
}
