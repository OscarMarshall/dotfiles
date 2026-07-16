# Generic Den <-> terranix wiring: any aspect can contribute a `terranix = {...};` class module
# (same shape as `nixos`/`darwin`/`homeManager`), scoped and merged per-host, turned into a
# `nix run .#<hostname>-tf` / `.#<hostname>-tf.plan` / `nix develop .#<hostname>-tf` Terraform
# workflow. See https://den.denful.dev/tutorials/terranix-demo/.
#
# A `terranix` field that's a FUNCTION requesting a den context arg (`host`, or a quirk like
# `virtual-host`) needs the `warnings-shim` below. Den's `wrapClassModule` attaches a
# collision-validator module (which sets a `warnings` output) to any such function;
# nixos/darwin/homeManager tolerate that fine (real NixOS-derived module types already have a
# `warnings` option), but terranix's own module type (upstream, not den) doesn't declare one, so
# `evalModules` throws "The option `warnings` does not exist" - not because of the value, just
# because nothing declared the option. `warnings-shim` declares it (default `[ ]`) so evaluation
# succeeds; terranix's own core (`core/default.nix`) then builds its final JSON by explicitly
# whitelisting only real Terraform keys (resource/variable/provider/etc.), so the shimmed
# `warnings` value never reaches config.tf.json regardless of its contents.
#
# Exposing a secret to Terraform: set `settings.terraform` on that secret's OWN entry under the
# aspect's `secrets` field (agenix-rekey's `age.secrets.<name>.settings` - a genuinely freeform
# `nullOr attrs` field agenix-rekey declares but never itself reads, so it's safe to use for our
# own bookkeeping - see https://github.com/oddlama/agenix-rekey). No separate quirk or list to keep
# in sync elsewhere; the secret's own declaration is the single source of truth for whether (and
# how) it reaches Terraform:
#
#   settings.terraform = true;        - a provider reads this straight from an env var (e.g.
#                                        Cloudflare's/Meraki's dashboard tokens) - exposed under
#                                        the env var `env-var-for` derives from the secret's OWN
#                                        name (kebab-case -> SCREAMING_SNAKE, e.g.
#                                        `cloudflare-api-token` -> `CLOUDFLARE_API_TOKEN`) - so name
#                                        the secret to match whatever env var the provider actually
#                                        reads.
#   settings.terraform = "variable";  - the value is a RESOURCE ATTRIBUTE (e.g. an OIDC client
#                                        secret Authentik's API has to persist), which nothing in
#                                        Terraform can read from an arbitrary env var - only from a
#                                        declared `variable`, populated via the `TF_VAR_*`
#                                        convention. Exposed as `TF_VAR_<env-var-for name>`; the
#                                        consuming aspect declares `variable.<env-var-for name>` in
#                                        its own `terranix` field and references
#                                        `"\${var.<env-var-for name>}"`.
#
# Every such secret, across every aspect on a host, is collected below into that host's own
# `"${host.name}-tf.env"` generated secret (create/update it like any other generated secret:
# `agenix generate -a && agenix rekey -a`) - `terraformWrapper.prefixText` decrypts and sources it
# automatically before every `nix run .#<hostname>-tf*` invocation, so there's no manual per-secret
# `source <(agenix -d ...)` step to remember (or to add to) when a new aspect starts contributing a
# credential.
#
# `settings.terraform = "variable"` secrets can end up in Terraform's STATE file in plaintext once
# applied (Terraform has to persist resource attributes to manage them - no env-var trick routes
# around that), and state for hosts like harmony is committed to this (public) repo (see
# .gitignore's comment, and #516). `terraform.encryption` below (contributed unconditionally for
# every host) is what actually keeps those out of the plaintext git history.
{
  den,
  inputs,
  lib,
  config,
  ...
}:
let
  warnings-shim = {
    options.warnings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  # kebab-case -> SCREAMING_SNAKE_CASE, e.g. `cloudflare-api-token` -> `CLOUDFLARE_API_TOKEN`.
  env-var-for = secret: lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] secret);

  # `sec.settings` is a declared option, default `null` - `a.b.c or default` short-circuits the
  # WHOLE chain (not just the last step), so this is safe even when `sec.settings` itself is
  # `null`. Returns `null` for anything not opted in, `true`/`"variable"` (or whatever else
  # `settings.terraform` was set to) otherwise.
  terraform-mode-of = sec: sec.settings.terraform or null;

  # The actual env var a `settings.terraform`-flagged secret surfaces as, per the two modes
  # documented above.
  terraform-env-var-for =
    name: sec: if terraform-mode-of sec == "variable" then "TF_VAR_${env-var-for name}" else env-var-for name;

  # Collects every `settings.terraform`-flagged secret, across every aspect on a host, into that
  # host's own `"${host.name}-tf.env"` generated secret - lives outside any single aspect (like
  # virtual-host.nix/port-forward.nix's consumers) since it's shared plumbing, not owned by any one
  # service. `os` (not `nixos`) so this works identically whichever platform a future
  # terraform-contributing host runs.
  terraform-secrets-aspect = { host, ... }: {
    secrets =
      {
        config,
        secrets,
        lib,
        ...
      }:
      let
        terraform-secrets = lib.filterAttrs (_: sec: terraform-mode-of sec != null) config.age.secrets;
      in
      {
        # Always present (not left to opt in) - it backs `terraform.encryption` below, which every
        # `<host>-tf` gets unconditionally (see that field's own comment for why).
        open-tofu-state-passphrase = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 32";
          intermediary = true;
          settings.terraform = "variable";
        };

        # This key's PRESENCE must be unconditional, even though `terraform-secrets` (its VALUE
        # depends on it) is empty exactly when only `open-tofu-state-passphrase` above is
        # flagged - making it conditional on `terraform-secrets != { }` would mean
        # `config.age.secrets`'s own key set depends on whether THIS module contributes this SAME
        # key, which depends on scanning `config.age.secrets`'s key set - "infinite recursion
        # encountered". A value may safely depend on the fully-merged `config.age.secrets` (lazy
        # evaluation handles that fine); a key's PRESENCE may not.
        "${host.name}-tf.env".generator = {
          dependencies = lib.mapAttrs (name: _: secrets.${name}) terraform-secrets;
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            lib.concatMapStrings (name: ''
              # %q (not a plain "%s") shell-quotes the decrypted value before it lands in the
              # generated env file - this file gets `source`d (see terraformWrapper.prefixText
              # below), so an unescaped value containing `$`, backticks, `\`, or `"` would be
              # reinterpreted by the shell instead of reproduced literally.
              printf '${terraform-env-var-for name terraform-secrets.${name}}=%q\n' "$(${decrypt} ${
                lib.escapeShellArg deps.${name}.file
              })"
            '') (lib.attrNames terraform-secrets);
        };
      };

    # Encrypts every `<host>-tf` state/plan at rest (OpenTofu's built-in state encryption, stable
    # since 1.8 - pinned opentofu is 1.12.3) - added repo-wide here, not per-aspect, since ANY
    # aspect's `terranix` field can start carrying a secret-bearing resource attribute (the
    # `settings.terraform = "variable"` convention above exists precisely for that), and state for
    # hosts like harmony is committed to this (public) repo (see .gitignore's comment, and #516).
    # Unconditional (not gated on whether any `settings.terraform` secret actually exists) because
    # this field can't see `config.age.secrets` to gate itself on - it's evaluated in terranix's
    # own module-type pass, which only den quirks bridge into (see this file's header comment), and
    # `age.secrets` isn't one.
    terranix = {
      variable.OPEN_TOFU_STATE_PASSPHRASE.sensitive = true;

      terraform.encryption = {
        key_provider.pbkdf2.main.passphrase = "\${var.OPEN_TOFU_STATE_PASSPHRASE}";

        method = {
          aes_gcm.main.keys = "\${key_provider.pbkdf2.main}";
          # No real key_provider - exists only so `state.fallback` below has something to name.
          # State written under this method is never produced going forward, only ever read.
          unencrypted.migrate = { };
        };

        # `method` (here and in `fallback` below) is a STATIC TRAVERSAL, not a computed value -
        # HCL's JSON spec requires this as a plain string containing raw HCL syntax
        # (`"method.aes_gcm.main"`), NOT a `"\${...}"` template - the latter parses as a template
        # expression and fails validate ("A single static variable reference is required ... No
        # ... template expressions ... allowed here"), even though `"\${...}"` is exactly right for
        # genuinely computed values elsewhere in this block (`key_provider.pbkdf2.main.passphrase`,
        # `aes_gcm.main.keys`).
        state = {
          method = "method.aes_gcm.main";
          # Every `<host>-tf/terraform.tfstate` committed before this (e.g. harmony's, from #516)
          # is still plaintext JSON - without a fallback, OpenTofu would try to decrypt that as
          # ciphertext and fail outright on the very next `plan`/`apply`. Read-only: the moment
          # anything applies, the state is rewritten through `method.aes_gcm.main` above and
          # stays encrypted from then on.
          #
          # `fallback` is a nested BLOCK in OpenTofu's schema (`fallback { method = ...; }`), not
          # a plain attribute like `method` above - a bare string here (rather than a JSON object)
          # fails at apply time ("Incorrect JSON value type ... Either a JSON object or a JSON
          # array is required, representing the contents of one or more \"fallback\" blocks"),
          # even though it looks identical to `method`'s own assignment in HCL. JSON syntax needs
          # the block's actual contents as an object, hence nesting one more level than `method`
          # does.
          fallback.method = "method.unencrypted.migrate";
        };
      };
    };
  };

  # Read from the file's own top-level `config` (closed over here, not re-requested) for the same
  # reason dns.nix's `perSystem` does the same for `config.flake.nixosConfigurations`: `config` is
  # ALSO the name flake-parts binds to each per-system module's own (different) result, so
  # requesting it again on the `perSystem` function below - needed there for the per-system
  # `config.agenix-rekey.package` - would silently shadow this outer one instead of erroring,
  # making `.flake.terranixModules` resolve to `{ }` and silently dropping every `<hostname>-tf`
  # package. Hoisting the lookup here, before that shadow exists, keeps both readable.
  terranix-modules = config.flake.terranixModules or { };
in
{
  flake-file.inputs.terranix = {
    url = "github:terranix/terranix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [ (inputs.terranix.flakeModule or { }) ];

  den = {
    classes.terranix = { };

    policies.host-to-terranix = { host, ... }: [
      (den.lib.policy.instantiate {
        name = "${host.name}-tf";
        class = "terranix";
        instantiate = { modules, ... }: modules;
        # `-tf` suffix (rather than the bare host name) avoids colliding with the
        # `packages.<host>` each host already gets from Den's `nh` battery (quick-rebuild
        # shortcuts) - terranix's flake-module keys `packages.<system>.<key>` off this same
        # intoAttr name.
        intoAttr = [
          "terranixModules"
          "${host.name}-tf"
        ];
      })
    ];

    schema.host.includes = [
      den.policies.host-to-terranix
      terraform-secrets-aspect
    ];
  };

  # Guarded on `inputs ? terranix`: the first `nix run .#write-flake` pass after adding this
  # module runs before flake.nix/flake.lock actually have a `terranix` input, so the option this
  # sets (declared by terranix's own flakeModule, imported above) doesn't exist yet either.
  perSystem =
    { config, pkgs, ... }:
    lib.optionalAttrs (inputs ? terranix) {
      terranix.terranixConfigurations = lib.mapAttrs (
        key: modules:
        let
          # Every entry here is keyed `"${host.name}-tf"` (see `intoAttr` above), so stripping the
          # suffix recovers the host name without needing `host` itself in this scope.
          host-name = lib.removeSuffix "-tf" key;
          env-file = "secrets/generated/${host-name}-tf.env.age";
        in
        {
          modules = modules ++ [ warnings-shim ];
          terraformWrapper = {
            package = pkgs.opentofu;
            # No-ops for hosts with no `settings.terraform`-flagged secrets (nothing to generate,
            # so the file never exists). Both tools are called by their full store path (not left
            # to PATH) so this works even outside the dev shell.
            #
            # agenix-rekey's own CLI (`config.agenix-rekey.package`, built from its
            # nix/package.nix) is NOT plain agenix/ragenix - it has no `-d` flag. `view` is its
            # decrypt-to-stdout equivalent (apps/edit-view.nix). It internally `cd`s to the flake
            # root before resolving its FILE argument, so that argument must already be absolute -
            # `realpath ..` resolves it relative to the terraform workdir's parent, since
            # terranix's own template (`mkdir -p ${workdir}; cd ${workdir}`, applied before
            # prefixText runs) always puts us exactly one directory below wherever `nix run` was
            # invoked from.
            prefixText = ''
              env_file="$(${pkgs.coreutils}/bin/realpath ..)/${env-file}"
              if [ -f "$env_file" ]; then
                set -a
                # shellcheck disable=SC1090 # dynamic path is intentional - see env_file above
                source <(${config.agenix-rekey.package}/bin/agenix view "$env_file")
                set +a
              fi
            '';
          };
        }
      ) terranix-modules;
    };
}
