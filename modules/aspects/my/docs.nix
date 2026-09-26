# User-facing documentation for everything this host serves: a static Zensical site (the successor to
# Material for MkDocs, from the same authors) built at evaluation time and served straight off the
# Nix store by nginx - no daemon, no database, nothing to back up. Prose lives in the repo's own
# top-level `docs/` directory (plain Markdown, one page per guide); anything that would otherwise
# drift out of date with the config - which services exist and where, which Minecraft worlds are
# up - is GENERATED here from the same data the rest of the host already consumes, so a service
# added to a host shows up in its docs without touching Markdown.
#
# Scope: only what's reachable from OUTSIDE the home network - the `virtual-host` services (every
# one has a public DNS record, see dns.nix) and anything with a `port-forward` (the Minecraft
# worlds). LAN-only things (Samba shares, the Satisfactory server) are left out on purpose, so
# everything documented here works for everyone it's documented for, wherever they are.
#
# Hand-written pages reference host-specific values through `@placeholder@` tokens (see
# `substitutions` below) rather than hard-coding them, the same `substituteAll` convention nixpkgs
# uses - so the prose doesn't bake in `host.domain` and friends, which are Nix values.
#
# Deliberately NOT `protected`: the whole point is that someone who has just been sent an invite -
# and so has no Authentik account yet - can read how to redeem it. Nothing on it is more sensitive
# than what public DNS already reveals (every hostname here is a public record - see dns.nix).
# Flip `protected = true;` below (and give it a `port`-backed location, since nginx.nix's
# forward-auth snippet only attaches to the auto-generated proxy location) if that ever changes.
#
# Preview locally without rebuilding a host:
#
#   nix build .#nixosConfigurations.harmony.config.services.nginx.virtualHosts.\"docs.harmony.silverlight-nex.us\".root
#   python -m http.server -d result
{
  my.docs =
    {
      global ? false,
    }:
    { host, ... }:
    let
      name = "docs";
      url = "${name}.${host.name}.${host.domain}";
    in
    {
      nixos =
        {
          config,
          lib,
          pkgs,
          virtual-host,
          ...
        }:
        let
          generated = {
            # Split out of `guides/games.md` (which covers how to join) into its own include, so
            # the world list tracks `services.minecraft-servers` - nix-minecraft's option set,
            # populated by my.minecraft-servers - rather than a hand-kept copy. Addresses are the
            # per-world SRV names minecraft-servers.nix's own `terranix` field publishes, so no
            # port is needed. Disabled worlds (still declared, e.g. to keep their data around) are
            # left out.
            "minecraft-worlds.md" =
              let
                worlds = lib.filterAttrs (_: server: server.enable) (config.services.minecraft-servers.servers or { });
              in
              if worlds == { } then
                "There are no Minecraft worlds running right now."
              else
                table [ "World" "Address" ] (
                  lib.mapAttrsToList (world: _: [
                    world
                    "`${world}.minecraft.${host.domain}`"
                  ]) worlds
                );
          };
          # Every hand-written page under `docs/guides/` is named after the `virtual-host.name` it
          # documents (`jellyfin.md` for `name = "jellyfin"`), so the Services table can link a row
          # to its guide by checking for the file, and a service with no guide yet just gets no
          # link rather than a broken one.
          guide-for = vh: if builtins.pathExists (source + "/guides/${vh.name}.md") then "guides/${vh.name}.md" else null;
          # The canonical, shortest name a service answers on - `<name>.<domain>` when `global`
          # (nginx.nix's `serverAliases`), otherwise the host-scoped one. Same derivation as
          # nginx.nix/homepage.nix's own `urlFor`, preferring the global alias since that's the one
          # worth handing to a person.
          hostname-of =
            vh: if vh.global or false then "${vh.name}.${host.domain}" else vh.url or "${vh.name}.${host.name}.${host.domain}";
          # Page order in the sidebar. Zensical would otherwise sort pages alphabetically, which puts
          # "Account" after "Files" and buries the guides under a generic "Guides" heading.
          nav = [
            { Welcome = "index.md"; }
            { "Your account" = "account.md"; }
            { Services = "services.md"; }
            {
              Guides = [
                { "Watch: Jellyfin" = "guides/jellyfin.md"; }
                { "Watch: Plex" = "guides/plex.md"; }
                { "Request: Seerr" = "guides/seerr.md"; }
                { "Photos: Immich" = "guides/immich.md"; }
                { "Files & office: Nextcloud" = "guides/nextcloud.md"; }
                { "Documents: Paperless-ngx" = "guides/paperless.md"; }
                { "Books: Storyteller" = "guides/storyteller.md"; }
                { "Game servers" = "guides/games.md"; }
              ];
            }
            { "Getting help" = "help.md"; }
          ];
          # Same string authentik.nix's own `open-group` binds - the one `virtual-host` group whose
          # applications every `user`-group member (not just `admin`) is granted. That binding is
          # a `let` inside authentik.nix's `terranix` field, unreachable from here, so it's
          # repeated rather than shared; if the two ever disagree, the Services page lists
          # something people can't open (or omits something they can).
          open-group = "Media";
          # The Services page as a whole (not just an include) - it's nothing but the table plus
          # a sentence, so there's no hand-written prose worth keeping in `docs/` for it.
          services-page = ''
            # Services

            Everything you can use with your account. The address is what to type into an app when it asks
            for a "server"; follow the guide link for step-by-step instructions.

            ${table [ "Service" "What it's for" "Address" "Guide" ] (
              map (vh: [
                "**${vh.label or vh.name}**"
                vh.homepage.description or ""
                "<https://${hostname-of vh}>"
                (lib.optionalString (guide-for vh != null) "[Guide](${guide-for vh})")
              ]) (lib.sortOn (vh: lib.toLower (vh.label or vh.name)) (lib.filter (vh: vh.group or null == open-group) virtual-host))
            )}

            Plex is the one exception to signing in with your account here — it uses your own
            [Plex account](guides/plex.md) instead.
          '';
          # Trimmed from `zensical new`'s own scaffold - just what these pages actually use.
          # `pymdownx.snippets` is what pulls `generated` above into the hand-written pages
          # (`--8<-- "minecraft-worlds.md"`), with `base_path` pointed at where the build below
          # drops them; `check_paths` turns a typo'd include into a build failure instead of a
          # silently empty section.
          settings = (pkgs.formats.toml { }).generate "zensical.toml" {
            project = {
              inherit nav;

              markdown_extensions = {
                admonition = { };
                attr_list = { };
                md_in_html = { };

                pymdownx = {
                  details = { };
                  keys = { };

                  snippets = {
                    base_path = [ "generated" ];
                    check_paths = true;
                  };

                  superfences = { };
                  tabbed.alternate_style = true;
                  tasklist.custom_checkbox = true;
                };

                toc.permalink = true;
              };

              site_description = "How to use the services running on ${host.name}.";
              site_name = "${lib.toSentenceCase host.name} Guide";
              site_url = "https://${if global then "${name}.${host.domain}" else url}/";

              theme = {
                features = [
                  "content.tabs.link"
                  "navigation.footer"
                  "navigation.indexes"
                  "navigation.instant"
                  "navigation.sections"
                  "navigation.top"
                  "search.highlight"
                ];

                language = "en";

                palette = [
                  {
                    media = "(prefers-color-scheme)";

                    toggle = {
                      icon = "lucide/sun-moon";
                      name = "Switch to light mode";
                    };
                  }
                  {
                    media = "(prefers-color-scheme: light)";
                    scheme = "default";

                    toggle = {
                      icon = "lucide/sun";
                      name = "Switch to dark mode";
                    };
                  }
                  {
                    media = "(prefers-color-scheme: dark)";
                    scheme = "slate";

                    toggle = {
                      icon = "lucide/moon";
                      name = "Switch to system preference";
                    };
                  }
                ];
              };
            };
          };
          site =
            pkgs.runCommand "${host.name}-docs"
              {
                nativeBuildInputs = [ pkgs.zensical ];
                passAsFile = [ "servicesPage" ];
                servicesPage = services-page;
              }
              ''
                cp -r --no-preserve=mode ${source} docs
                cp "$servicesPagePath" docs/services.md
                cp ${settings} zensical.toml

                mkdir generated
                ${lib.concatStrings (
                  lib.mapAttrsToList (file: text: ''
                    cp ${pkgs.writeText file text} generated/${file}
                  '') generated
                )}

                # A loop rather than `find -exec`, since substituteInPlace is a stdenv shell
                # function, not an executable `find` could call.
                find docs -name '*.md' -print0 | while IFS= read -r -d "" page; do
                  substituteInPlace "$page" ${
                    lib.concatStrings (
                      lib.mapAttrsToList (key: value: " --replace-quiet @${key}@ ${lib.escapeShellArg value}") substitutions
                    )
                  }
                done

                # Zensical writes a build cache under $HOME by default; the sandbox's HOME is
                # /homeless-shelter, which doesn't exist.
                export HOME=$TMPDIR
                zensical build --strict
                mv site $out
              '';
          source = ../../../docs;
          # The `@key@` tokens hand-written pages may use - see this file's header comment.
          substitutions = {
            inherit (host) domain;
            admin = "Oscar";
            auth = config.services.authentik.nginx.host;
          };
          # Markdown tables are the one place prose would otherwise have to repeat the config, so
          # every table here is rendered from Nix instead. `|` is the only character that would
          # break a cell, and nothing below ever produces one.
          table =
            header: rows:
            lib.concatStringsSep "\n" (
              [
                "| ${lib.concatStringsSep " | " header} |"
                "| ${lib.concatStringsSep " | " (map (_: "---") header)} |"
              ]
              ++ map (row: "| ${lib.concatStringsSep " | " row} |") rows
            );
        in
        {
          # No `port` on the `virtual-host` below, so nginx.nix builds no proxy location for this
          # vhost - just the TLS/alias/DNS plumbing - and this fills in the one thing it serves.
          services.nginx.virtualHosts.${url}.root = site;
        };

      virtual-host = {
        inherit global name;
        group = "Infra";
        homepage.description = "User guides for everything here";
        host = host.name;
        icon = "mdi-book-open-page-variant";
        label = "Docs";
      };
    };
}
