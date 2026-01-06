_: {
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      user = {
        name = "Oscar Marshall";
        email = "oscar.lim.marshall@gmail.com";
      };
    };
  };
}
