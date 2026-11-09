"""Confere a configuração do Calamares do XInguOS (usado pelo tests/instalador.bats)."""
import pathlib
import sys

import yaml

cal = pathlib.Path(sys.argv[1])
s = yaml.safe_load(open(cal / "settings.conf", encoding="utf-8"))
execs = [m for passo in s["sequence"] for k, v in passo.items() if k == "exec" for m in v]
shows = [m for passo in s["sequence"] for k, v in passo.items() if k == "show" for m in v]
todos = set(execs) | set(shows)

for conf in (cal / "modules").glob("*.conf"):
    nome = conf.stem.replace("shellprocess_pos", "shellprocess@pos")
    assert nome in todos, f"{conf.name} não está na sequência"

ordem = execs.index
assert (ordem("partition") < ordem("mount") < ordem("unpackfs") < ordem("users")
        < ordem("shellprocess@pos") < ordem("bootloader") < ordem("umount")), execs
assert s["branding"] == "xinguos" and (cal / "branding/xinguos/show.qml").exists()

u = yaml.safe_load(open(cal / "modules/users.conf", encoding="utf-8"))
assert "live" in u["user"]["forbidden_names"]
assert u["sudoersGroup"] == "wheel" and u["setRootPassword"] is False

m = yaml.safe_load(open(cal / "modules/mount.conf", encoding="utf-8"))
assert {v["subvolume"] for v in m["btrfsSubvolumes"]} == {"/@", "/@home", "/@snapshots", "/@log", "/@cache"}
assert "compress=zstd" in next(o for o in m["mountOptions"] if o["filesystem"] == "btrfs")["options"]

p = yaml.safe_load(open(cal / "modules/partition.conf", encoding="utf-8"))
assert p["defaultFileSystemType"] == "btrfs" and p["initialSwapChoice"] == "none"

b = yaml.safe_load(open(cal / "branding/xinguos/branding.desc", encoding="utf-8"))
assert b["strings"]["bootloaderEntryName"] == "XInguOS"
print("calamares: ok")

f = yaml.safe_load(open(cal / "modules/fstab.conf", encoding="utf-8"))
for chave in ("default", "ssd"):
    assert isinstance(f["tmpOptions"][chave], dict), "tmpOptions precisa ser mapa (Calamares 3.4)"
    assert "tmpfs" in f["tmpOptions"][chave] and "options" in f["tmpOptions"][chave]
assert p.get("enableLuksAutomatedPartitioning") is False, "sem initcpiocfg/luks: não oferecer criptografia"
print("calamares (fstab/luks): ok")
