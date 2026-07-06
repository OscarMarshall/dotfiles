{ den, ... }: {
  den.hosts.aarch64-darwin."Oscars-MacBook-Pro.local" = {
    graphical = true;
    work = true;

    users.oscar = { };
  };

  den.hosts.x86_64-linux.harmony.users.oscar = { };

  den.hosts.x86_64-linux.melaan = {
    graphical = true;

    users = {
      adelline = { };
      oscar = { };
    };
  };

  den.homes.x86_64-linux."omarshal@dev203.meraki.com" = {
    aspect = den.aspects.oscar;
    work = true;
  };
}
