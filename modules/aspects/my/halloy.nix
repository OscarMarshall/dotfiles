let
  # Default nick; a network's own `nickname` overrides it.
  defaultNickname = "OscarMarshall";
  # Ports, TLS and auth styles come from autobrr's indexer definitions
  # (internal/indexer/definitions/*.yaml). `nickserv` sends NICKSERV IDENTIFY after connecting;
  # `server` sends the secret as the connection PASS (LST's IRC key, seedpool's passkey).
  networks = {
    darkpeers = {
      auth = "nickserv";
      nickname = "Ashamed";
      server = "irc.darkpeers.org";
    };

    # Joining #announce also needs `/msg ENDOR !invite <user> <irckey>`, sent by hand.
    digitalcore = {
      auth = "nickserv";
      port = 7000;
      server = "irc.digitalcore.club";
    };

    # The nick must be the site username.
    lst = {
      auth = "server";
      nickname = "ashamed";
      server = "irc.lst.gg";
    };

    myanonamouse = {
      auth = "nickserv";
      nickname = "AshamedMunchkin";
      server = "irc.myanonamouse.net";
    };

    # No autobrr definition; Halloy's 6697/TLS defaults are a guess.
    p2p-network = {
      auth = "nickserv";
      nickname = "Ashamed";
      server = "irc.p2p-network.net";
    };

    seedpool = {
      auth = "server";
      nickname = "Ashamed";
      server = "irc.seedpool.com";
    };

    torrentleech = {
      auth = "nickserv";
      nickname = "AshamedMunchkin";
      port = 7021;
      server = "irc.torrentleech.org";
    };
  };
in
{
  my.halloy = { user, ... }: {
    homeManager = { lib, pkgs, ... }: {
      programs.halloy = {
        enable = true;

        settings.servers = lib.mapAttrs (
          _:
          {
            auth,
            server,
            nickname ? defaultNickname,
            port ? null,
          }:
          let
            # Each secret is the `password` field of the Proton Pass item titled after the server host.
            # Halloy runs this via `sh -c`, which - launched from the desktop rather than a shell -
            # never sees home.sessionVariables, so the keyring provider my.proton-pass sets has to be
            # repeated here or pass-cli looks for its DB key in the wrong store. Halloy treats a failing
            # command as a config error and refuses to start at all, so a missing item (a network not
            # yet registered) or a locked pass-cli must fall back to an empty secret: NickServ just
            # rejects the blank IDENTIFY, and a blank PASS only fails that one network's login.
            passwordCommand = lib.concatStringsSep " " [
              "PROTON_PASS_LINUX_KEYRING=dbus"
              (lib.getExe' pkgs.proton-pass-cli "pass-cli")
              "item view --vault-name Personal --item-title ${server} --field password --output human"
              "2>/dev/null || true"
            ];
          in
          {
            inherit nickname server;
            ${if auth == "server" then "password_command" else "nick_password_command"} = passwordCommand;
            channels = [ ];
          }
          // lib.optionalAttrs (port != null) { inherit port; }
        ) networks;
      };
    };

    # Chat history and logs; the config itself is Home Manager-managed. `preserve`
    # (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [ ".local/share/halloy" ];
  };
}
