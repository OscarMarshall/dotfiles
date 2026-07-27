# The `torrent-client` quirk: qbittorrent.nix (the one place that actually knows qBittorrent's real
# connection details - namespace, host, port) contributes ONE entry describing itself; any aspect
# that needs to point at it (Radarr/Sonarr/Bookshelf's own devopsarr terranix download-client
# resources, cross-seed's own JSON config) reads that entry and formats it however its own config
# shape requires. Mirrors virtual-host.nix's shape (one or more contributors, independent consumers
# who each decide what to do with the data) rather than a Den "forward", which would prescribe the
# shape consumers receive it in.
#
# Record shape:
#   kind - (required) identifies which torrent client this is - currently always "qbittorrent",
#          kept as a field (rather than assumed by every consumer) in case a second client is ever
#          added and a consumer needs to tell them apart.
#   host - (required) address consumers should connect to.
#   port - (required) port consumers should connect to.
{
  den.quirks.torrent-client.description = "Torrent client connection details (currently just qBittorrent), consumed by *arr aspects and cross-seed";
}
