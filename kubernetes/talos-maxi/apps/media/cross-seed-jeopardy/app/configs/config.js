// Torrent content layout: Original
// Default Torrent Management Mode: Automatic
// Default Save Path: /media/downloads/torrents/complete
// Incomplete Save Path: /media/downloads/torrents/incomplete

module.exports = {
  delay: 30,
  apiKey: process.env.CROSS_SEED_API_KEY,
  transmissionRpcUrl: "http://transmission-jeopardy.media.svc.cluster.local:9091/transmission/rpc",

  torznab: [
    `http://prowlarr.media.svc.cluster.local:80/2/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,   // BHD
    `http://prowlarr.media.svc.cluster.local:80/67/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // MTV
    `http://prowlarr.media.svc.cluster.local:80/66/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // BTN
  ],

  action: "inject",
  matchMode: "safe",
  duplicateCategories: true,

  includeNonVideos: true,
  includeSingleEpisodes: true,

  linkCategory: "cross-seed",
  linkType: "hardlink",
  linkDir: "/jeopardy/downloads/cross-seed",

  outputDir: "/config",
  torrentDir: "/transmission/torrents",

  rssCadence: "15 minutes"
};
