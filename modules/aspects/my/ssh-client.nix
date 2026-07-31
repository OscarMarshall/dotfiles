# Hosts that declare a `lan-ip` (see modules/den.nix) get a same-named SSH alias for free, but only
# for whoever has an account there under the same den aspect as whoever's applying this config -
# i.e. the same person, matched by aspect identity rather than by username, since the username on
# each side can differ (e.g. omarshal on work machines vs oscar elsewhere). `ssh harmony` then
# resolves to that host's LAN IP and logs in as whatever that matching account is actually named.
{ config, lib, ... }:
let
  lanHosts = lib.pipe config.den.hosts [
    builtins.attrValues
    (map builtins.attrValues)
    lib.flatten
    (builtins.filter (host: host ? lan-ip))
  ];
in
{
  my.ssh-client =
    {
      home ? null,
      user ? null,
      ...
    }:
    let
      aliases = lib.concatMap (
        host:
        let
          matchingUser = lib.findFirst (u: u.aspect == aspect) null (builtins.attrValues host.users);
        in
        lib.optional (matchingUser != null) {
          inherit (host) name;

          value = {
            HostName = host.lan-ip;
            User = matchingUser.userName;
          };
        }
      ) lanHosts;
      aspect = user.aspect or home.aspect or null;
    in
    {
      homeManager.programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        settings = lib.listToAttrs aliases // {
          "*" = {
            AddKeysToAgent = "no";
            Compression = false;
            ControlMaster = "no";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "no";
            ForwardAgent = false;
            HashKnownHosts = false;
            ServerAliveCountMax = 3;
            ServerAliveInterval = 0;
            UserKnownHostsFile = "~/.ssh/known_hosts";
          };
        };
      };
    };
}
