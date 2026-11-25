# qBittorrent music

After the first rollout or after resetting qBittorrent's settings, enable **Run on torrent finished** under **Options → Downloads → Run external program** and save this command:

```text
/scripts/qbittorrent-complete.sh %K %I "%D" "%R"
```

In **Options → Web UI**, leave **Bypass authentication for clients on localhost** enabled. Nemorosa and the completion hook use the qBittorrent API over pod loopback; they do not require a subnet whitelist or a separate WebUI credential.

The hook notifies Nemorosa, writes `origin.yaml` in the torrent root for RED and OPS, and asks wrtag to copy downloads saved directly under `/music/downloads`. Torrents without a root directory or v1 infohash are sent to Nemorosa but skip origin generation and wrtag. Nemorosa's webhook is not exposed by a Service, and its hardlinks are separate from Transmission's at `/music/downloads/nemorosa-qbittorrent`.
