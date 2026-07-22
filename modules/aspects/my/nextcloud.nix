let
  domain = "silverlight-nex.us";
in
{
  my.nextcloud =
    {
      global ? false,
    }:
    { host, ... }:
    let
      url = "nextcloud.${host.name}.${domain}";
    in
    {
      dataset = {
        name = "nextcloud";
        pool = "metalminds";
      };

      nixos = { config, pkgs, ... }: {
        # Public DNS for this hostname resolves off-box; on-box callers (notably coolwsd's
        # server-side WOPI CheckFileInfo/GetFile requests back to Nextcloud) hit it too and hairpin
        # through the router - or worse, since this host's AAAA record points at an address that's
        # simply unreachable from harmony, causing coolwsd's outbound HTTP client (which tries IPv6
        # first, unlike curl's happy-eyeballs fallback) to hang for a full 60s timeout rather than
        # fail fast. Confirmed via `journalctl -u coolwsd`: "CheckTimeout: Timeout while requesting
        # ... after 60072ms", and directly reproduced with `curl -6` to the resolved address hanging
        # to its own timeout. Pinning to loopback here sidesteps both problems for every on-box
        # self-reference; nginx still serves the right vhost by Host header, over the real
        # Let's Encrypt cert. External browsers use public DNS and are unaffected.
        networking.hosts."127.0.0.1" = [ url ];

        services = {
          nextcloud = {
            config = {
              adminpassFile = config.age.secrets.nextcloud-admin-password.path;
              adminuser = "admin";
              dbtype = "pgsql";
            };

            enable = true;
            package = pkgs.nextcloud34;
            database.createLocally = true;
            datadir = "/metalminds/nextcloud"; # holds both config/ (config.php) and data/ (user files)

            extraApps = with config.services.nextcloud.package.packages.apps; {
              inherit richdocuments user_oidc;
            };

            hostName = url;
            https = true;
            # The default (8 MB) is sized for a stock install; interned_strings_buffer holds
            # deduplicated string literals from compiled PHP opcode, and Nextcloud's larger codebase
            # keeps filling it, so OPcache warns that the buffer is nearly full and can't cache new
            # strings effectively.
            phpOptions."opcache.interned_strings_buffer" = "16";

            settings = {
              # Lets phone numbers be entered without a country code in profile settings; matches
              # time.timeZone = America/Los_Angeles.
              default_phone_region = "US";
              # Drops the username/password form from /login, leaving just the "Log in with
              # Authentik" button - the alternative-logins block sits OUTSIDE the form's `v-if` in
              # core's Login.vue, so SSO survives being hidden.
              #
              # This is friction, not a security boundary, and Nextcloud means it that way: the same
              # view re-renders the form for `?direct=1`, so /login?direct=1 remains the way in for
              # the local `admin` account if Authentik is ever down. Little is lost by that - the
              # OIDC-provisioned accounts have no password to type in the first place (user_oidc is
              # their backend), so `admin` was already the only account a form could authenticate.
              hide_login_form = true;
              mail_domain = domain;
              # `mail_smtphost`/`mail_smtpport`/`mail_smtpauth` are left at their module defaults
              # (127.0.0.1:25, unauthenticated) - that's exactly the local Postfix relay set up
              # below, which submission on loopback doesn't need SASL for. `mail_from_address` is
              # config.php's local-part convention (combined with `mail_domain` into a full
              # address), not a full address itself.
              mail_from_address = "nextcloud";
              # Hour (server-local, i.e. time.timeZone = America/Los_Angeles) at which the daily
              # background-job cron runs its heavy tasks - picked for low usage.
              maintenance_window_start = 2;
              overwriteprotocol = "https";
              # Silences the "server identifier isn't configured" admin warning. Only matters when
              # several PHP servers share one Nextcloud install (e.g. behind a load balancer) and
              # need to tell each other's log/lock entries apart - harmony is the only PHP server
              # here, so any value in the allowed 0-1023 range is equally a no-op.
              serverid = 0;
            };
          };

          # Outbound-only relay so Nextcloud (mail_smtphost = 127.0.0.1 above, a module default) has
          # somewhere to hand mail off to. Proton doesn't accept direct SMTP delivery from arbitrary
          # servers, hence relaying through its own submission endpoint with a per-address SMTP
          # token rather than attempting direct-to-recipient delivery.
          postfix = {
            enable = true;
            # Compiled to /var/lib/postfix/conf/sasl_passwd.db; the plaintext source is the secret
            # itself (see its declaration above) since its only content is credentials, not a mix of
            # public config and a secret value to template together.
            mapFiles."sasl_passwd" = config.age.secrets.nextcloud-postfix-smtp-passwd.path;

            settings.main = {
              # Restricts every postfix listener (including `submission`/`smtps`, left disabled
              # above anyway) to loopback, and restricts relaying to loopback callers - this box
              # isn't meant to accept mail from the network, only from Nextcloud on the same host.
              inet_interfaces = "loopback-only";
              myhostname = "${host.name}.${domain}";
              mynetworks = [ "127.0.0.0/8" ];
              relayhost = [ "[smtp.protonmail.ch]:587" ];
              smtp_sasl_auth_enable = true;
              smtp_sasl_password_maps = "hash:/var/lib/postfix/conf/sasl_passwd";
              smtp_sasl_security_options = "noanonymous";
              smtp_tls_security_level = "encrypt";
            };
          };
        };

        # Everything Nextcloud keeps as app-level DB state rather than in config.php, and so has no
        # `services.nextcloud` option to set: wiring user_oidc -> Authentik, richdocuments ->
        # Collabora, and turning shipped apps off. Renamed from
        # `nextcloud-authentik-richdocuments-setup` once that list stopped being two things worth
        # enumerating in a unit name.
        systemd.services.nextcloud-occ-setup = {
          description = "Apply Nextcloud app-level config that has no NixOS option, via occ";
          wantedBy = [ "multi-user.target" ];

          after = [
            "nextcloud-setup.service"
            "coolwsd.service"
            "nginx.service"
          ];

          path = [ config.services.nextcloud.occ ];
          requires = [ "nextcloud-setup.service" ];

          script = ''
            set -euo pipefail

            # `user_oidc:provider` is an UPSERT keyed on the identifier - its own class is
            # `UpsertProvider`, and it calls `createOrUpdateProvider()` - so it needs no
            # create-vs-update branch. There is no `--update` option (passing one aborts the whole
            # unit before it can correct anything), which is worth stating because getting this
            # wrong FAILS SILENTLY in the worst way: the very first run creates the provider and
            # succeeds, and only later runs - the ones meant to carry a changed `discoveryuri` or a
            # rotated secret into Nextcloud - die, leaving a provider frozen at whatever the first
            # run happened to write. That's exactly how Nextcloud ended up pointing at Authentik's
            # old pre-`global` hostname, which no longer resolves, and reporting only "Could not
            # reach the OpenID Connect provider" at login.
            #
            # `--clientsecret-file` rather than `--clientsecret`: the latter would put the secret in
            # this unit's argv, briefly readable via /proc/<pid>/cmdline by any local user. occ reads
            # and trims the file itself.
            #
            # `--unique-uid=0` turns OFF user_oidc's default of hashing identifiers
            # (`LocalIdService.getId`: sha256 of "<providerId>_0_<id>" when it's on, the raw value
            # when it's off). It governs GROUP gids as much as user ids, so it's what makes both of
            # the settings below land as readable names rather than hex. Flipping it later
            # re-identifies everyone - existing accounts become unreachable and log in as new,
            # empty ones - so it's effectively permanent once anyone has files.
            #
            # `--mapping-uid=preferred_username` is required alongside it: the uid claim defaults to
            # `sub` (`SETTING_MAPPING_UID_DEFAULT`), which authentik derives as a hash
            # (`sub_mode = hashed_user_id`), so `--unique-uid=0` alone would just swap our hash for
            # authentik's. Authentik's default `profile` scope supplies `preferred_username`.
            #
            # `--group-provisioning=1` syncs Nextcloud group membership from the `groups` claim on
            # each login, and it's AUTHORITATIVE: user_oidc removes an OIDC user from any group
            # absent from the claim, so don't hand-assign groups to these accounts - Authentik is
            # the only place that sticks. This is also what grants admin, without a mapping layer:
            # user_oidc creates each group under the claim value verbatim, and Nextcloud confers
            # administrator rights on exactly the group whose gid is `admin` - hence that group
            # being singular in authentik.nix. The local `admin` account is untouched by any of
            # this (it never logs in through OIDC) and stays the way back in.
            #
            # Values are literal 0/1: occ coerces every boolean setting with `$value === '0' ? '0' :
            # '1'`, so `false` would silently mean TRUE.
            nextcloud-occ user_oidc:provider "authentik" \
              --clientid="nextcloud" \
              --clientsecret-file="$CREDENTIALS_DIRECTORY/oidc-client-secret" \
              --discoveryuri="https://${config.services.authentik.nginx.host}/application/o/nextcloud/.well-known/openid-configuration" \
              --scope="openid email profile" \
              --unique-uid=0 \
              --mapping-uid=preferred_username \
              --mapping-groups=groups \
              --group-provisioning=1

            # Sends /login straight to Authentik instead of rendering a page whose only control is
            # the "Log in with Authentik" button. Despite the name, this is purely that redirect -
            # user_oidc only acts on it for a top-level HTML navigation to /login, and only when
            # exactly one provider is configured (AppInfo/Application.php); it takes nothing away.
            #
            # This is an APP config rather than a `services.nextcloud.settings` (config.php) one,
            # hence occ. `--lazy` is not optional: user_oidc reads the key with `lazy: true`, and a
            # non-lazy write lands somewhere it won't look. It defaults to "1" (allow), so "0" is
            # what enables the redirect - the inverse of how it reads.
            #
            # `?direct=1` opts out of this too, the same escape hatch `hide_login_form` above
            # honours, so one URL still reaches the form for the local `admin` account.
            nextcloud-occ config:app:set user_oidc allow_multiple_user_backends --value=0 --lazy

            # coolwsd's net.proto is forced to IPv4 (see collabora-online.nix) since net.listen =
            # "loopback" otherwise binds [::1] only on this host, which nginx's proxyPass
            # (nginx.nix, always 127.0.0.1) can't reach. That leaves coolwsd IPv4-only, so this
            # discovery URL has to target 127.0.0.1, not [::1] - the latter no longer listens.
            nextcloud-occ config:app:set richdocuments wopi_url --value="http://127.0.0.1:9980"
            nextcloud-occ config:app:set richdocuments public_wopi_url --value="https://collabora.${host.name}.${domain}"
            nextcloud-occ config:app:set richdocuments wopi_allowlist --value="::1,127.0.0.1"

            # Immich (immich.nix) is the photo library here, so Nextcloud's own Photos tab is just a
            # second, worse gallery over the same account's files. `photos` ships with Nextcloud
            # rather than coming from `extraApps`, so there's no `services.nextcloud` option that
            # leaves it out - disabling after the fact is the only lever. Safe to re-run: occ
            # short-circuits with "No such app enabled" and exits 0 rather than failing this unit's
            # `set -e` on every subsequent boot.
            nextcloud-occ app:disable photos

            # Every OIDC-provisioned account has no local password (user_oidc is their backend),
            # so Nextcloud's own password-complexity rules have nothing to enforce against there -
            # only the local `admin` break-glass account has a password, and Authentik doesn't
            # touch it. Shipped app, so - as with `photos` above - disabling is the only lever, and
            # it's the same safe-to-re-run no-op once already disabled.
            nextcloud-occ app:disable password_policy

            # OIDC-provisioned accounts authenticate entirely through Authentik and never see
            # Nextcloud's native 2FA prompt, so this is really about the local `admin` break-glass
            # account: its login form is still reachable (`?direct=1`, see `hide_login_form`
            # above), it has no password_policy backing it anymore (disabled above), and it's the
            # one account Authentik being down wouldn't protect. Idempotent - re-running with
            # `--on` when already enforced is a no-op.
            nextcloud-occ twofactorauth:enforce --on
          '';

          serviceConfig = {
            LoadCredential = "oidc-client-secret:${config.age.secrets.nextcloud-oidc-client-secret.path}";
            Type = "oneshot";
            User = "nextcloud";
          };
        };
      };

      secrets = { secrets, ... }: {
        nextcloud-admin-password.generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 24";

        # `settings.terraform = "variable";` feeds a Terraform `variable` (modules/terranix.nix's
        # two modes); also read directly below (LoadCredential) to configure user_oidc via occ,
        # so it's NOT `intermediary` - it has to be materialized as a real host secret too.
        nextcloud-oidc-client-secret = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          settings.terraform = "variable";
        };

        nextcloud-postfix-smtp-passwd.generator = {
          dependencies = { inherit (secrets) nextcloud-postfix-smtp-token; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf '[smtp.protonmail.ch]:587 nextcloud@${domain}:%s\n' "$(${decrypt} ${lib.escapeShellArg deps.nextcloud-postfix-smtp-token.file})"
            '';
        };

        # The raw SMTP token itself - an external credential from Proton, not something this
        # repo can generate, so there's no `generator` here. Author it by hand once via `agenix
        # edit secrets/nextcloud-postfix-smtp-token.age` with just the token (Proton Settings ->
        # All settings -> IMAP/SMTP -> SMTP tokens - NOT the account password), then `agenix
        # rekey -a`. `intermediary` because nothing reads this directly - only the generator
        # below, which folds it into Postfix's actual sasl_passwd map line.
        nextcloud-postfix-smtp-token = {
          intermediary = true;
          rekeyFile = ../../../secrets/nextcloud-postfix-smtp-token.age;
        };
      };

      virtual-host = {
        inherit global;
        group = "Media";
        homepage.description = "Files, calendar & office suite";
        host = host.name;
        icon = "nextcloud.svg";
        label = "Nextcloud";
        name = "nextcloud";

        # Deliberately no `port` — Nextcloud is PHP-FPM, not a plain HTTP service to
        # proxy_pass to. The quirk emits only forceSSL/enableACME for this vhost, and
        # Nextcloud's own module below supplies its `locations`/`root`, merging cleanly.
        #
        # Requests the matching OAuth2 Provider + Application from Authentik (authentik.nix) - see
        # virtual-host.nix's `oidc` field for the shape. Per user_oidc's own callback route (and
        # Authentik's Nextcloud integration guide) - `/index.php/...` only matters for installs
        # that haven't set `overwriteprotocol`-style pretty URLs, which this one has (see
        # `settings.overwriteprotocol` below).
        oidc = {
          client-secret = "nextcloud-oidc-client-secret";
          redirect-paths = [ "/apps/user_oidc/code" ];
        };
      };
    };
}
