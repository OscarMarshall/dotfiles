# The `preserve` quirk: any aspect contributes one alongside its `nixos` / `hmLinux` config to
# have a filesystem path bind-mounted from `/persist` on hosts with an ephemeral root
# (my.preservation - currently just tensoon, see modules/aspects/hosts/tensoon/disk.nix). Declared
# once here and consumed by my.preservation; lives in its own file, like port-forward.nix /
# virtual-host.nix, since it no longer belongs to any single consumer.
#
# Why a quirk rather than a direct `preservation.preserveAt` definition: the `preservation.*`
# options only exist where `inputs.preservation.nixosModules.default` is imported, which happens
# only inside my.preservation, included only by tensoon. An aspect like my.orca-slicer (pulled in
# by modules/aspects/users/oscar/oscar.nix, so present on every host oscar has an account on -
# harmony, melaan, the Mac, the dev203 home) that referenced `preservation.*` directly would fail
# to evaluate everywhere else with "The option `preservation` does not exist". Emitting a
# `preserve` quirk instead is inert on any host without my.preservation: the value is collected
# scope-locally and simply never read.
#
# Record shape - a fragment of `preservation.preserveAt."/persist"` (see the preservation flake's
# options.nix for the full submodule):
#
#   directories                    - system paths, each a bare "/var/lib/foo" string or an attrset
#                                    { directory; mode?; how?; inInitrd?; mountOptions?;
#                                    configureParent?; }.
#   files                          - system files, same shape with `file` instead of `directory`.
#   users.<name>.directories/files - per-user paths, interpreted relative to that user's home.
#
# A home-directory contribution comes from a user-scoped aspect (hmLinux/homeManager, included
# per-user), so it takes the den `user` context arg and stamps its own `user.userName`; the
# `expose-preserve` policy (registered in modules/aspects/defaults.nix) then lifts it to the host
# scope where my.preservation's consumer reads it (den's pipe.expose - user-scope quirk data
# flowing up to the parent host). A system contribution comes from a host-scoped aspect (or the
# host aspect itself) and lands in the host scope directly, no exposure needed.
#
# A value may be a `{ config, ... }:` thunk when a path depends on a NixOS option.
{ den, ... }: {
  den = {
    # Lift user-scope `preserve` contributions up to the host scope, where my.preservation consumes
    # them. A no-op at the root scope and for any scope that emits nothing, so it is safe as an
    # unconditional default (registered in modules/aspects/defaults.nix, alongside den's own
    # hostname / define-user batteries).
    policies.expose-preserve =
      _:
      let
        inherit (den.lib.policy) pipe;
      in
      [ (pipe.from "preserve" [ pipe.expose ]) ];

    quirks.preserve.description = "Filesystem paths bind-mounted from /persist on ephemeral-root hosts (my.preservation)";
  };
}
