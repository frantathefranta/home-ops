// Torrent content layout: Original
// Default Torrent Management Mode: Automatic
// Default Save Path: /media/downloads/torrents/complete
// Incomplete Save Path: /media/downloads/torrents/incomplete

module.exports = {
  action: "inject",
  apiKey: process.env.CROSS_SEED_API_KEY,
  delay: 30,
  duplicateCategories: false,
  includeEpisodes: true,
  includeNonVideos: false,
  includeSingleEpisodes: true,
  linkCategory: "cross-seed",
  linkDir: "/jeopardy/downloads/cross-seed",
  linkType: "hardlink",
  matchMode: "safe",
  outputDir: "/tmp",
  port: Number(process.env.CROSS_SEED_PORT),
  skipRecheck: true,
  torrentDir: "/config/torrents",
  transmissionRpcUrl: "http://transmission-jeopardy.media.svc.cluster.local:9091/transmission/rpc",
  torznab: [],
  //   `http://prowlarr.media.svc.cluster.local:80/2/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,   // BHD
  //   `http://prowlarr.media.svc.cluster.local:80/67/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // MTV
  //   `http://prowlarr.media.svc.cluster.local:80/66/api?apikey=$${process.env.PROWLARR__AUTH__APIKEY}`,  // BTN
  // ],
};
