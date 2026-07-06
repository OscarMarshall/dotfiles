{ den, ... }: {
  den.hosts = {
    aarch64-darwin.OMARSHAL-M-2FD2 = {
      graphical = true;
      work = true;

      users.oscar.userName = "omarshal";
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
