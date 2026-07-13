{
  my.fonts.os = { pkgs, ... }: {
    fonts.packages = with pkgs; [
      maple-mono.NF
      nerd-fonts.symbols-only
    ];
  };
}
