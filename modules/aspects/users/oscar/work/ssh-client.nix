let
  aliases = toString (
    [
      dev-alias
      shard-alias
    ]
    ++ jump-host-aliases
  );
  dev-alias = "dev*";
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
  shard-alias = "n*";
in
{
  den.aspects.oscar.provides.work.provides.ssh-client = {
    hmDarwin.programs.ssh.settings."*.meraki.com ${aliases}".UseKeychain = "yes";

    homeManager = { lib, ... }: {
      programs.ssh.settings = {
        "*.meraki.com ${aliases}" = {
          AddKeysToAgent = "yes";
          ForwardAgent = true;
          ServerAliveInterval = 240;
          User = "omarshal";
        };

        "dev" = lib.hm.dag.entryBefore [ "meraki.com aliases" ] { HostName = "dev203.meraki.com"; };

        "gerrit.ikarem.io" = {
          User = "omarshal";
        };

        "github-meraki" = {
          HostName = "github.com";
          IdentitiesOnly = true;
          IdentityFile = "${./id_ed25519_meraki.pub}";
          User = "git";
        };

        "meraki.com aliases" = lib.hm.dag.entryBefore [ "*.meraki.com" "n*.meraki.com" ] {
          HostName = "%h.meraki.com";
          header = "Host !*.meraki.com ${aliases}";
        };

        "n*.meraki.com ${shard-alias}" = {
          HostKeyAlgorithms = "+ssh-rsa";
          ProxyJump = builtins.head jump-host-aliases;
        };
      };
    };
  };
}
