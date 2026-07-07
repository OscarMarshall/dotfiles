{ my, ... }:
let
  profileName = "default";
in
{
  den.aspects.oscar.provides.zen-browser = {
    includes = [ my.zen-browser ];

    homeManager = {
      programs.zen-browser = {
        darwinDefaultsId = "app.zen-browser.zen";

        # No-op on Darwin (it only wires up xdg.mimeApps); already the actual
        # default browser here via macOS's LaunchServices, set outside Nix.
        setAsDefaultBrowser = true;

        policies = {
          # Updates come from `nix flake update` + rebuild; the browser's own
          # updater can't write into the read-only /nix/store install anyway.
          DisableAppUpdate = true;
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          DisableFeedbackCommands = true;
          DontCheckDefaultBrowser = true;
          NoDefaultBookmarks = true;
          DisablePocket = true;
          OfferToSaveLogins = false;
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };

          ExtensionSettings =
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
              "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = mkExtension "styl-us";
            };
        };

        profiles.${profileName}.settings = {
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
      stylix.targets.zen-browser.profileNames = [ profileName ];
    };
  };
}
