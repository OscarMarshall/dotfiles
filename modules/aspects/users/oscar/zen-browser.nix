{
  den.aspects.oscar.provides.zen-browser.homeManager = {
    programs.zen-browser = {
      darwinDefaultsId = "app.zen-browser.zen";

      policies.ExtensionSettings =
        let
          mkExtension = slug: {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
            installation_mode = "force_installed";
          };
        in
        {
          "78272b6fa58f4a1abaac99321d503a20@proton.me" = mkExtension "proton-pass";
          "firefox@tampermonkey.net" = mkExtension "tampermonkey";
          "jid1-MnnxcxisBPnSXQ@jetpack" = mkExtension "privacy-badger17";
          "addon@darkreader.org" = mkExtension "darkreader";
          "uBlock0@raymondhill.net" = mkExtension "ublock-origin";
          "@testpilot-containers" = mkExtension "multi-account-containers";
        };

      profiles.default.settings = {
        "zen.view.compact.enable-at-startup" = true;
        "zen.workspaces.force-container-workspace" = true;
        "zen.workspaces.continue-where-left-off" = true;
        "sidebar.visibility" = "hide-sidebar";
        "signon.rememberSignons" = false;
        "browser.contentblocking.category" = "standard";
      };
    };

    # Required for theming to apply: the module system can't both detect
    # declared zen-browser profile names and use them, so it's repeated here.
    stylix.targets.zen-browser.profileNames = [ "default" ];
  };
}
