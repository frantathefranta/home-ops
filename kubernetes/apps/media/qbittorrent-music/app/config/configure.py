import configparser
import shutil
from pathlib import Path

path = Path("/config/qBittorrent/qBittorrent.conf")
path.parent.mkdir(parents=True, exist_ok=True)
fresh = not path.exists()
if fresh:
    shutil.copyfile("/defaults/qBittorrent.conf", path)

# Qt keys are case-sensitive; disable interpolation to preserve passwords and paths.
config = configparser.ConfigParser(interpolation=None, delimiters=("=",))
config.optionxform = str
config.read(path, encoding="utf-8")
if not config.has_section("BitTorrent"):
    config.add_section("BitTorrent")

# Enforce disabled DHT on every start, including restored/existing state.
config.set("BitTorrent", r"Session\DHTEnabled", "false")
if fresh:
    config.set("BitTorrent", r"Session\DefaultSavePath", "/music/downloads/")
    config.set("BitTorrent", r"Session\TempPath", "/music/downloads/incomplete/")
    config.set("BitTorrent", r"Session\TempPathEnabled", "true")

temporary = path.with_suffix(".conf.tmp")
with temporary.open("w", encoding="utf-8") as handle:
    config.write(handle, space_around_delimiters=False)
shutil.copymode(path, temporary)
temporary.replace(path)
