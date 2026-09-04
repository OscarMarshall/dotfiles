{
  my.fonts = {
    # Toolkit font resolution - what stylix.fonts used to drive. Linux-only; Darwin has no
    # fontconfig. Maple Mono NF for monospace, Inter for everything else.
    nixos.fonts.fontconfig.defaultFonts = {
      monospace = [ "Maple Mono NF" ];
      sansSerif = [ "Inter" ];
      serif = [ "Inter" ];
    };

    os = { pkgs, ... }: {
      fonts.packages = with pkgs; [
        inter
        maple-mono.NF
        nerd-fonts.symbols-only
      ];
    };
  };
}
