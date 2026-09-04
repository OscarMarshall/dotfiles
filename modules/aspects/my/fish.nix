{
  my.fish.homeManager.programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # Fish 4.4+ bundles Catppuccin (with light/dark variants baked into
      # each flavor) as a built-in theme; `theme choose` re-applies whichever
      # variant matches the terminal's reported background color, and reacts
      # live when that changes (e.g. Ghostty switching between its own
      # light/dark themes).
      fish_config theme choose catppuccin-mocha

      # GH_TOKEN from Proton Pass (Personal / "GH_TOKEN" item, "API Key" field). Guarded: only
      # when it's unset and pass-cli is on PATH, and any error or empty result is swallowed so a
      # logged-out or locked pass-cli never breaks shell startup. `pass-cli login` once per boot
      # unlocks the local DB; the pam_keyinit wiring in my.noctalia-greeter is what lets pass-cli
      # reach its keyring key at all.
      if not set -q GH_TOKEN; and type -q pass-cli
          set -l gh_token (command pass-cli item view --vault-name Personal --item-title GH_TOKEN --field 'API Key' --output human 2>/dev/null)
          test -n "$gh_token"; and set -gx GH_TOKEN $gh_token
      end
    '';
  };
}
