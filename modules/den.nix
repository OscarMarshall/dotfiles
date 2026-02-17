{
  den.homes.x86_64-linux.omarshal = {
    stateVersion = "25.11";
    aspect = "oscar";
    work = true;
  };

  den.hosts.aarch64-darwin.OMARSHAL-M-2FD2 = {
    graphical = true;
    work = true;

    users.oscar.userName = "omarshal";
  };

  den.hosts.x86_64-linux.harmony.users.oscar = { };

  den.hosts.x86_64-linux.melaan = {
    graphical = true;

    users = {
      adelline = { };
      oscar = { };
    };
  };
}
