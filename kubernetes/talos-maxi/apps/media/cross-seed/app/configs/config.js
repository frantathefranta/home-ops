// Torrent content layout: Original
// Default Torrent Management Mode: Automatic
// Default Save Path: /media/downloads/torrents/complete
// Incomplete Save Path: /media/downloads/torrents/incomplete

module.exports = {
  delay: 30,
  apiKey: process.env.CROSS_SEED_API_KEY,
  qbittorrentUrl: "http://qbittorrent.media.svc.cluster.local:8080",

  torznab: [
    `http://prowlarr.media.svc.cluster.local:80/2/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,   // BHD
    `http://prowlarr.media.svc.cluster.local:80/60/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // HDB
    `http://prowlarr.media.svc.cluster.local:80/67/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // MTV
    `http://prowlarr.media.svc.cluster.local:80/68/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // PTP
    `http://prowlarr.media.svc.cluster.local:80/7/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,   // UHD
    `http://prowlarr.media.svc.cluster.local:80/66/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // BTN
    `http://prowlarr.media.svc.cluster.local:80/69/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // AB
  ],

  action: "inject",
  matchMode: "safe",
  duplicateCategories: true,

  includeNonVideos: true,
  includeEpisodes: true,
  includeSingleEpisodes: true,

  // The save paths for sonarr/radarr are set to the following:
  dataDirs: [
    "/media/downloads/tv-sonarr",
    "/media/downloads/radarr",
    "/media/downloads/anime-sonarr",
  ],

  linkCategory: "cross-seed",
  linkType: "hardlink",
  linkDir: "/media/downloads/xseed",

  outputDir: "/config",
  torrentDir: "/qbittorrent/qBittorrent/BT_backup",

  rssCadence: "15 minutes"
};
