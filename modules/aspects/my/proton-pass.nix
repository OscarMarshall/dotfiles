{ den, ... }:
let
  # pass-cli defaults to PROTON_PASS_LINUX_KEYRING=kernel, storing its DB encryption key in the
  # kernel key-retention service - which is wiped on every reboot, so a login never survives one.
  # `dbus` puts the key in the Secret Service (gnome-keyring) instead: file-backed and unlocked by
  # pam_gnome_keyring at password login (see my.noctalia-greeter). Paired with preserving
  # ~/.local/share/proton-pass-cli, the session then persists across reboots. Only read on Linux; a
  # fingerprint-only login leaves the keyring locked until it's unlocked.
  linuxKeyProvider = "dbus";
in
{
  my.proton-pass = {
    includes = [ (den._.unfree [ "proton-pass-cli" ]) ];
    # Upstream defaults this agent to the launchd "user" domain, which has no
    # window-server session. Keychain access for the DB encryption key needs
    # the Aqua session (the "gui" domain) or it fails with -25308
    # (errSecInteractionNotAllowed).
    hmDarwin.launchd.agents.proton-pass-agent.domain = "gui";

    hmLinux = {
      home.sessionVariables.PROTON_PASS_LINUX_KEYRING = linuxKeyProvider;
      # home.sessionVariables only reaches shells - systemd --user does not import it. Without this
      # the agent's `pass-cli ssh-agent start` falls back to the kernel provider while the shell
      # uses dbus; the two key stores diverge and every agent start rewrites pass-cli.db with a key
      # the shell can't read. Same value, one source, so they can't drift.
      systemd.user.services.proton-pass-agent.Service.Environment = [ "PROTON_PASS_LINUX_KEYRING=${linuxKeyProvider}" ];
    };

    homeManager.services.proton-pass-agent.enable = true;
  };
}
