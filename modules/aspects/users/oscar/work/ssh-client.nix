let
  dev-alias = "dev*";
  shard-alias = "n*";
  jump-host-aliases = [
    "sva0"
    "sf100"
    "sf201"
    "dal0"
    "fra0"
    "mun0"
    "sin0"
    "syd0"
  ];
  aliases = toString (
    [
      dev-alias
      shard-alias
    ]
    ++ jump-host-aliases
  );
in
{
  den.aspects.oscar.provides.work.provides.ssh-client = {
    homeManager =
      { lib, ... }:
      {
        programs.ssh.matchBlocks = {
          "*.meraki.com ${aliases}" = {
            addKeysToAgent = "yes";
            forwardAgent = true;
            identityFile = "~/.ssh/id_ed25519_meraki";
            serverAliveInterval = 240;
          };
          "dev" = lib.hm.dag.entryBefore [ "meraki.com aliases" ] { hostname = "dev203.meraki.com"; };
          "meraki.com aliases" = lib.hm.dag.entryBefore [ "*.meraki.com" "n*.meraki.com" ] {
            host = "!*.meraki.com ${aliases}";
            hostname = "%h.meraki.com";
          };
          "n*.meraki.com ${shard-alias}" = {
            proxyJump = builtins.head jump-host-aliases;
            extraOptions.HostKeyAlgorithms = "+ssh-rsa";
          };
        };
      };
    hmDarwin.programs.ssh.matchBlocks."*.meraki.com ${aliases}".extraOptions.useKeychain = "yes";
  };
}
