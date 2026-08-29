{ my, ... }:
let
  profileName = "default";
in
{
  den.aspects.oscar.provides.zen-browser = {
    includes = [ my.zen-browser ];

    homeManager = { lib, pkgs, ... }: {
      programs.zen-browser = {
        darwinDefaultsId = "app.zen-browser.zen";
        # The nixpkgs Firefox wrapper (which this flake reuses) hard-sets
        # MOZ_LEGACY_PROFILES=1, forcing the profile root to ~/.zen. But this flake's HM module
        # writes profiles.ini / user.js under $XDG_CONFIG_HOME/zen, so none of `profiles.*` ever
        # took effect. Blanking the var (Gecko treats empty as unset) moves Zen onto ~/.config/zen
        # where the module already writes. `env` is Linux-only and injected after the wrapper's own
        # --set, so it wins. Existing ~/.zen profile is abandoned - extensions return via the
        # force_installed policy, logins via Proton Pass.
        env.MOZ_LEGACY_PROFILES = "";

        policies = {
          AutofillAddressEnabled = false;
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
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # Zen's own wheel/touchpad scroll delta runs fast on the Framework 13 panel even under
          # Umbriel's scroll_factor; 30 = 0.3x the Firefox default of 100. Linux-only - macOS
          # trackpad scrolling in Zen is not part of this compounding.
          "mousewheel.default.delta_multiplier_x" = 30;
          "mousewheel.default.delta_multiplier_y" = 30;
        };

        # No-op on Darwin (it only wires up xdg.mimeApps); already the actual
        # default browser here via macOS's LaunchServices, set outside Nix.
        setAsDefaultBrowser = true;
      };
    };
  };
}
