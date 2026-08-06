# Bans IPs that repeatedly fail authentication. harmony's DNS records are `proxied = false`
# (dns.nix) and its port-forward rules aren't restricted to Cloudflare's IPs (nginx.nix), so real
# client traffic - and real attacker traffic - reaches nginx directly; the origin server has to be
# its own first line of defense, not just an edge WAF.
#
# The sshd jail comes free from NixOS's fail2ban module once `services.openssh.enable` is on
# (ssh-server.nix) - no config needed here. The nginx jails below need an explicit `backend =
# "auto"` override since NixOS's module defaults every jail's backend to "systemd" (right for
# openssh's journald logs, wrong for nginx's file-based ones).
{
  my.fail2ban.nixos.services.fail2ban = {
    enable = true;

    jails = {
      # Catches vulnerability-scanner probing (PHP shells, wp-login, etc.) that shows up in
      # nginx's error log as 400s/404s for paths none of our vhosts serve.
      nginx-botsearch.settings.backend = "auto";
      # Netdata's API vhost (netdata.nix) is the only virtual host still gated on HTTP Basic
      # Auth instead of Authentik forward-auth - this is what actually catches repeated
      # failures against it.
      nginx-http-auth.settings.backend = "auto";
    };
  };
}
