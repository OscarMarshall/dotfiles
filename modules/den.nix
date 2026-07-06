{ den, ... }: {
  den.hosts = {
    aarch64-darwin.Oscars-MacBook-Pro = {
      graphical = true;
      work = true;

      users.oscar = { };
    };

    x86_64-linux = {
      harmony.users.oscar = { };

      melaan = {
        graphical = true;

        users = {
          adelline = { };
          oscar = { };
        };
      };
    };
  };

  den.homes.x86_64-linux."omarshal@dev203.meraki.com" = {
    aspect = den.aspects.oscar;
    work = true;
  };
}
