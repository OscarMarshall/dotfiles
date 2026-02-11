{
  oscarmarshall.git = user: {
    homeManager.programs.git = {
      enable = true;
      settings = {
        inherit user;
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };
  };
}
