# Explicitly sets podman's unqualified-search registries, rather than relying on NixOS's own
# default `virtualisation.containers.registries.settings` (which only ever emits bare `[[registry]]
# location = "..."` blocks for docker.io/quay.io - registering them as KNOWN registries, but not, in
# current containers/image versions, as ones podman will actually guess for a short (unqualified)
# image name). Older podman/skopeo releases treated a bare `[[registry]]` block as implicitly
# search-eligible (a legacy v1-format fallback), which is why short image names (e.g.
# `wolveix/satisfactory-server`, satisfactory-server.nix) worked fine for a long time - until some
# nixpkgs bump pulled in a podman/containers-common release that dropped that fallback, silently
# breaking every SHORT (non-fully-qualified) `virtualisation.oci-containers` image reference on this
# host with `short-name "..." did not resolve to an alias and no unqualified-search registries are
# defined in "/etc/containers/registries.conf"` - surfaced by rreading-glasses.nix's own images,
# the first ones in a long while that needed a genuinely fresh pull rather than an already-cached
# one. `docker.io`/`quay.io` match the exact pair NixOS's own default already registers, so this
# restores the behavior every existing short-named image (already fully-qualified, going forward,
# see rreading-glasses.nix's own comment on why) implicitly relied on.
{
  my.podman.nixos.virtualisation.containers.registries.settings.unqualified-search-registries = [
    "docker.io"
    "quay.io"
  ];
}
