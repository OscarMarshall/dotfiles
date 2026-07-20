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

        policies = {
          # Updates come from `nix flake update` + rebuild; the browser's own
          # updater can't write into the read-only /nix/store install anyway.
          DisableAppUpdate = true;
          DisableFeedbackCommands = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableTelemetry = true;
          DontCheckDefaultBrowser = true;

          EnableTrackingProtection = {
            Cryptomining = true;
            Fingerprinting = true;
            Locked = true;
            Value = true;
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
              "@testpilot-containers" = mkExtension "multi-account-containers";
              "addon@darkreader.org" = mkExtension "darkreader";
              "firefox@tampermonkey.net" = mkExtension "tampermonkey";
              "jid1-MnnxcxisBPnSXQ@jetpack" = mkExtension "privacy-badger17";
              "uBlock0@raymondhill.net" = mkExtension "ublock-origin";
              "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = mkExtension "styl-us";
            };

          NoDefaultBookmarks = true;
          OfferToSaveLogins = false;
        };

        profiles.${profileName}.settings = {
          "browser.contentblocking.category" = "standard";
          "sidebar.visibility" = "hide-sidebar";
          "signon.rememberSignons" = false;
          "zen.view.compact.enable-at-startup" = true;
          "zen.workspaces.continue-where-left-off" = true;
          "zen.workspaces.force-container-workspace" = true;
        };

        # No-op on Darwin (it only wires up xdg.mimeApps); already the actual
        # default browser here via macOS's LaunchServices, set outside Nix.
        setAsDefaultBrowser = true;
      };

      stylix = {
        targets = {
          zen-browser = {
            # Zen already follows the system light/dark appearance on its own, which
            # conflicts with Stylix's injected (single-flavor) userChrome/userContent
            # CSS. Disable the CSS injection and let Zen handle its own theming.
            enableCss = false;
            # Required for theming to apply: the module system can't both detect
            # declared zen-browser profile names and use them, so it's repeated here.
            profileNames = [ profileName ];
          };
        };
      };
    };
  };
}
