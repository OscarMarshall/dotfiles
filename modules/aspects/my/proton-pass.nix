{ den, ... }: {
  my.proton-pass = {
    includes = [ (den._.unfree [ "proton-pass-cli" ]) ];
    # Upstream defaults this agent to the launchd "user" domain, which has no
    # window-server session. Keychain access for the DB encryption key needs
    # the Aqua session (the "gui" domain) or it fails with -25308
    # (errSecInteractionNotAllowed).
    hmDarwin.launchd.agents.proton-pass-agent.domain = "gui";
    homeManager.services.proton-pass-agent.enable = true;
  };
}
