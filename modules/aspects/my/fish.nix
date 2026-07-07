{
  my.fish.homeManager = {
    programs.fish = {
      enable = true;

      # Fish 4.4+ bundles Catppuccin (with light/dark variants baked into
      # each flavor) as a built-in theme; `theme choose` re-applies whichever
      # variant matches the terminal's reported background color, and reacts
      # live when that changes (e.g. Ghostty switching between its own
      # light/dark themes).
      interactiveShellInit = "fish_config theme choose catppuccin-mocha";
    };

    # Superseded by the reactive theme above; Stylix's target only ever sets
    # the static (dark-only) base16 colors.
    stylix.targets.fish.enable = false;
  };
}
