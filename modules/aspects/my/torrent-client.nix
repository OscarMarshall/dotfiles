# The `torrent-client` quirk: any *arr aspect (Radarr/Sonarr/Readarr/...) contributes one to get a
# devopsarr `<kind>_download_client_qbittorrent` Terraform resource pointed at qBittorrent -
# aggregated and filled in with qBittorrent's own connection details by qbittorrent.nix's own
# `terranix` field (modules/aspects/my/qbittorrent.nix), the one place that actually knows
# qBittorrent's real host/port/namespace (and whether a login is even needed there - see that
# file's `AuthSubnetWhitelist` comment). Mirrors virtual-host.nix's shape (many contributors, one
# aggregator), but inverted: qbittorrent.nix is the CONSUMER here, not a contributor - this keeps
# every *arr aspect from having to know qBittorrent's connection details itself.
#
# Record shape:
#   kind     - (required) which devopsarr Terraform provider/resource family this becomes -
#              "radarr" -> radarr_download_client_qbittorrent, "sonarr" ->
#              sonarr_download_client_qbittorrent, "readarr" -> readarr_download_client_qbittorrent.
#              That aspect's own `terranix` field must already declare
#              `terraform.required_providers.<kind>`.
#   name     - (required) short identifier, unique per entry - becomes both the Terraform resource
#              key and the qBittorrent category name.
#   provider - (optional) Terraform provider ALIAS to attach the resource to, for a `kind` with more
#              than one live instance (e.g. `"audiobooks"`/`"ebooks"` for the two Bookshelf/Readarr
#              instances, each with its own aliased `provider.readarr` block) - omit for a `kind`
#              with only one instance, where the provider is unaliased.
#   priority - (optional, default 1) devopsarr's own download-client `priority` field.
{
  den.quirks.torrent-client.description = "Radarr/Sonarr/Readarr download-client connections to qBittorrent, aggregated into Terraform resources by qbittorrent.nix";
}
