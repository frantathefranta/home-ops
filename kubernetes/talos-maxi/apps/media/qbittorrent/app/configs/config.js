// Torrent content layout: Original
// Default Torrent Management Mode: Automatic
// Default Save Path: /media/downloads/torrents/complete
// Incomplete Save Path: /media/downloads/torrents/incomplete

module.exports = {
  delay: 60,
  port: process.env.PORT || 2468,
  qbittorrentUrl: "http://localhost:8080",

  torznab: [
    `http://prowlarr.arrs.svc.cluster.local:9696/2/api?apikey=${process.env.PROWLARR__API_KEY}`,   // BHD
    `http://prowlarr.arrs.svc.cluster.local:9696/60/api?apikey=${process.env.PROWLARR__API_KEY}`,  // HDB
    `http://prowlarr.arrs.svc.cluster.local:9696/67/api?apikey=${process.env.PROWLARR__API_KEY}`,  // MTV
    `http://prowlarr.arrs.svc.cluster.local:9696/68/api?apikey=${process.env.PROWLARR__API_KEY}`,  // PTP
    `http://prowlarr.arrs.svc.cluster.local:9696/7/api?apikey=${process.env.PROWLARR__API_KEY}`,   // UHD
    `http://prowlarr.arrs.svc.cluster.local:9696/66/api?apikey=${process.env.PROWLARR__API_KEY}`,  // BTN
    `http://prowlarr.arrs.svc.cluster.local:9696/69/api?apikey=${process.env.PROWLARR__API_KEY}`,  // AB
  ],

  apiAuth: false,
  action: "inject",
  matchMode: "safe",
  skipRecheck: true,
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

  linkType: "hardlink",
  linkDir: "/media/downloads/xseed",

  outputDir: "/config/xseed",
  torrentDir: "/config/qBittorrent/BT_backup",

  rssCadence: "15 minutes"
};
