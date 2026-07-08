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
    homeManager = { lib, ... }: {
      programs.ssh.settings = {
        "github-meraki" = {
          HostName = "github.com";
          User = "git";
          IdentityFile = "${./id_ed25519_meraki.pub}";
          IdentitiesOnly = true;
        };
        "*.meraki.com ${aliases}" = {
          AddKeysToAgent = "yes";
          ForwardAgent = true;
          ServerAliveInterval = 240;
        };
        "dev" = lib.hm.dag.entryBefore [ "meraki.com aliases" ] { HostName = "dev203.meraki.com"; };
        "meraki.com aliases" = lib.hm.dag.entryBefore [ "*.meraki.com" "n*.meraki.com" ] {
          header = "Host !*.meraki.com ${aliases}";
          HostName = "%h.meraki.com";
        };
        "n*.meraki.com ${shard-alias}" = {
          ProxyJump = builtins.head jump-host-aliases;
          HostKeyAlgorithms = "+ssh-rsa";
        };
      };
    };
    hmDarwin.programs.ssh.settings."*.meraki.com ${aliases}".UseKeychain = "yes";
  };
}
