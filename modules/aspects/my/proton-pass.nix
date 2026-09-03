{ den, ... }: {
  my.proton-pass = {
    includes = [ (den._.unfree [ "proton-pass-cli" ]) ];
    # Upstream defaults this agent to the launchd "user" domain, which has no
    # window-server session. Keychain access for the DB encryption key needs
    # the Aqua session (the "gui" domain) or it fails with -25308
    # (errSecInteractionNotAllowed).
    hmDarwin.launchd.agents.proton-pass-agent.domain = "gui";
    # pass-cli defaults to PROTON_PASS_LINUX_KEYRING=kernel, storing its DB encryption key in the
    # kernel key-retention service - which is wiped on every reboot, so a login never survives one.
    # `dbus` puts the key in the Secret Service (gnome-keyring) instead, which is file-backed and
    # unlocked by pam_gnome_keyring at password login (see my.noctalia-greeter). Paired with
    # preserving ~/.local/share/proton-pass-cli, the session then persists across reboots. Only
    # read on Linux; a fingerprint-only login leaves the keyring locked until it's unlocked.
    hmLinux.home.sessionVariables.PROTON_PASS_LINUX_KEYRING = "dbus";
    homeManager.services.proton-pass-agent.enable = true;
  };
}
