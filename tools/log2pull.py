"""Turn boss pulls from a WoW combat log into paste strings for Dynamic Planner's analyzer.

Addons cannot read files, so this runs outside the game (Python 3 standard library only):

  py tools\\log2pull.py                      the last boss pull of the newest log, straight to the clipboard
  py tools\\log2pull.py --pick               pick pulls of the newest log from a list
  py tools\\log2pull.py --wow "D:\\Games\\World of Warcraft"   look for logs in this install (quote paths with spaces)
  py tools\\log2pull.py LOG --list           list the boss pulls (raw encounter numbers, 10 s or longer)
  py tools\\log2pull.py LOG --pull 18        one pull (raw encounter number, as listed)
  py tools\\log2pull.py LOG --all-boss 3429 --difficulty 16    every pull of one boss and difficulty

Logs are looked for in <wow>\\_retail_\\Logs and its RaiderIOLogsArchive subfolder of every World of Warcraft install
found (C:, D: and E:, the usual Program Files folders, the Blizzard registry entry, or --wow / the WOW_DIR variable),
and the newest file by modification time wins.

The log is opened read-only and streamed line by line (logs run to hundreds of MB). Output: one .txt per pull in
--out (default: pulls\\ next to this tool's folder), and the string for the first pull on the clipboard (clip.exe).
In game: /dynplan analyzer, Import pull, paste. A big pull is split into numbered parts the addon puts back together.

String format DPL1 (all integers base 36, times in tenths of a second, damage in whole points,
per-second damage (T and R records) in thousands):
  DPL1/<key>/<part>/<parts>/<check>/<chunk>     chunks join into the body; check = byte sum mod 36^4 of the chunk
  body: sections split by "~", records by ";", fields by ",", lists inside a field by "." and ":".
"""
import argparse
import csv
import glob
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

VERSION = "DPL1"
PART = 30000          # characters per part (one paste each)
MIN_PULL = 10.0       # seconds; shorter pulls are hidden from the list
RECAP = 8             # last hits kept per death
RECAP_WINDOW = 10.0   # seconds before a death those hits may come from
MAX_SPELLS = 60
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DRIVES = ("C:", "D:", "E:")
INSTALLS = ("World of Warcraft", r"Program Files (x86)\World of Warcraft", r"Program Files\World of Warcraft")
DAMAGE = {"SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE", "RANGE_DAMAGE", "SWING_DAMAGE", "SWING_DAMAGE_LANDED",
          "ENVIRONMENTAL_DAMAGE", "DAMAGE_SPLIT"}
SPELLISH = ("SPELL_", "RANGE_")
B36 = "0123456789abcdefghijklmnopqrstuvwxyz"


def b36(n):
    n = int(round(n))
    if n < 0:
        return "-" + b36(-n)
    if n < 36:
        return B36[n]
    out = []
    while n:
        n, r = divmod(n, 36)
        out.append(B36[r])
    return "".join(reversed(out))


def ds(t):
    return b36(max(0, round(t * 10)))


def clean(s):
    # Field and list separators, the edit box escape character and control characters never go into a string.
    return re.sub(r"[~;,.:/|\^\x00-\x1f]", " ", s or "").strip()


def stamp(text):
    local, _, off = text.rpartition("-")
    if not local or "/" not in local:  # positive offsets: "+3"
        local, _, off = text.rpartition("+")
        sign = 1
    else:
        sign = -1
    dt = datetime.strptime(local, "%m/%d/%Y %H:%M:%S.%f")
    try:
        return dt.replace(tzinfo=timezone(sign * timedelta(hours=int(off))))
    except ValueError:
        return dt.replace(tzinfo=timezone.utc)


def split(line):
    """b'<time>  EVENT,a,b' -> (time text, fields) or None."""
    try:
        text = line.decode("utf-8", "replace").rstrip("\r\n")
        when, payload = text.split("  ", 1)
    except ValueError:
        return None
    return when, next(csv.reader([payload]))


def short(name):
    # "Name-Realm-US" -> "Name-Realm" (the region adds nothing in a raid)
    parts = (name or "").split("-")
    if len(parts) >= 3 and len(parts[-1]) <= 3 and parts[-1].isupper():
        parts = parts[:-1]
    return "-".join(parts)


def is_guid(v):
    return v.startswith(("Player-", "Creature-", "Vehicle-", "Pet-", "GameObject-"))


def advanced(a):
    """Index of the 19-field advanced block (v22), or None."""
    k = a[0]
    base = 12 if k.startswith(SPELLISH) or k == "DAMAGE_SPLIT" else 10 if k == "ENVIRONMENTAL_DAMAGE" else 9
    if len(a) >= base + 19 and is_guid(a[base]):
        return base
    return None


def damage(a):
    """(spellId, name, amount, overkill, hp after or None, max hp or None) for a damage event."""
    k = a[0]
    block = advanced(a)
    base = 12 if k.startswith(SPELLISH) or k == "DAMAGE_SPLIT" else 10 if k == "ENVIRONMENTAL_DAMAGE" else 9
    hp = mx = None
    if block is not None:
        base = block + 19
        try:
            hp, mx = int(a[block + 2]), int(a[block + 3])
        except ValueError:
            pass
    if len(a) < base + 3:
        return None
    if k.startswith(SPELLISH) or k == "DAMAGE_SPLIT":
        sid, name = int(a[9]), a[10]
    elif k.startswith("SWING_"):
        sid, name = 88163, "Melee"
    else:
        sid, name = 0, a[9].title()  # environmental: Falling, Lava, ...
    try:
        return sid, name, int(a[base]), int(a[base + 2]), hp, mx
    except ValueError:
        return None


# ---------- Addon data: cooldown catalog and spec classes ----------
def catalog():
    """Spell IDs worth listing as cooldown casts: raid, personal and external cooldowns, plus their aliases."""
    ids = set()
    text = open(data_file("Cooldowns.lua"), encoding="utf-8").read()
    for m in re.finditer(r'\{\["id"\]=(\d+)[^{}]*?\["type"\]="(\w+)"', text):
        if m.group(2) in ("raid", "personal", "external"):
            ids.add(int(m.group(1)))
    alias = open(data_file("Aliases.lua"), encoding="utf-8").read()
    for a, b in re.findall(r"\[(\d+)\]=(\d+)", alias):
        if int(b) in ids:
            ids.add(int(a))
    return ids


def spec_classes():
    text = open(data_file("Specs.lua"), encoding="utf-8").read()
    return {int(i): c.upper() for i, c in re.findall(r'\["id"\]=(\d+),\["class"\]="(\w+)"', text)}


# ---------- Pass 1: list the encounters ----------
def index(path):
    pulls = []
    cur = None
    offset = 0
    n = 0
    with open(path, "rb") as src:
        for line in src:
            here = offset
            offset += len(line)
            if b"ENCOUNTER_" not in line[:60]:
                continue
            got = split(line)
            if not got:
                continue
            when, a = got
            if a[0] == "ENCOUNTER_START" and len(a) >= 5:
                n += 1
                cur = {"n": n, "enc": int(a[1]), "name": a[2], "diff": int(a[3]), "size": int(a[4]), "start": when,
                       "offset": here}
            elif a[0] == "ENCOUNTER_END" and cur and len(a) >= 6 and int(a[1]) == cur["enc"]:
                cur["kill"] = a[5] == "1"
                cur["end"] = when
                cur["endOffset"] = offset
                cur["dur"] = (stamp(when) - stamp(cur["start"])).total_seconds()
                pulls.append(cur)
                cur = None
    return pulls


DIFF = {14: "Normal", 15: "Heroic", 16: "Mythic", 17: "LFR", 8: "Mythic+", 23: "Mythic 5", 1: "Normal 5", 2: "Heroic 5"}


def describe(p):
    m, s = divmod(int(round(p["dur"])), 60)
    return "%4d  %-28s %-8s %2d:%02d  %-4s  %s" % (p["n"], p["name"][:28], DIFF.get(p["diff"], str(p["diff"])), m, s,
                                                  "kill" if p["kill"] else "wipe", p["start"].split(".")[0])


# ---------- Pass 2: one pull ----------
def parse(path, pull, cds, classes):
    t0 = stamp(pull["start"])
    players = {}      # guid -> record
    order = []
    names = {}        # guid -> name
    owner = {}        # pet guid -> player guid
    spells = {}       # spellId -> {name, src, total, over, hits: {pi: [amount, count]}}
    seconds = defaultdict(lambda: defaultdict(int))   # spellId -> second -> amount
    raid = defaultdict(int)
    recent = defaultdict(list)                        # player guid -> [(t, sid, name, amt, over, hp, src)]
    maxhp = {}
    deaths, casts, ints, disps = [], [], [], []
    boss_max = {}     # hostile npc guid -> (max hp, name)
    boss_hp = defaultdict(dict)                       # guid -> second -> pct
    pending_swing = {}

    def pidx(g):
        p = players.get(g)
        return p["i"] if p else None

    def hit(t, g, sid, name, src, amt, over, hp, mx):
        if amt <= 0 and over <= 0:
            return
        i = pidx(g)
        if i is None:
            return
        s = spells.get(sid)
        if not s:
            s = spells[sid] = {"name": name, "src": src, "total": 0, "over": 0, "hits": {}}
        s["total"] += amt
        s["over"] += max(0, over)
        h = s["hits"].setdefault(i, [0, 0])
        h[0] += amt
        h[1] += 1
        sec = int(t)
        seconds[sid][sec] += amt
        raid[sec] += amt
        players[g]["taken"] += amt
        if mx:
            maxhp[g] = mx
        lst = recent[g]
        lst.append((t, sid, name, amt, over, hp, src))
        if len(lst) > 40:
            del lst[:-40]

    with open(path, "rb") as src:
        src.seek(pull["offset"])
        for line in src:
            got = split(line)
            if not got:
                continue
            when, a = got
            k = a[0]
            t = (stamp(when) - t0).total_seconds()
            if k == "ENCOUNTER_END":
                break
            if k == "COMBATANT_INFO":
                g = a[1]
                if g not in players:
                    spec = int(a[25]) if len(a) > 25 and a[25].isdigit() else 0
                    players[g] = {"i": len(order) + 1, "guid": g, "spec": spec, "c": classes.get(spec, ""), "taken": 0,
                                  "ints": 0, "disp": 0}
                    order.append(g)
                continue
            if len(a) < 9 or k.startswith("ENCOUNTER_"):
                continue
            sg, sn, tg, tn = a[1], a[2], a[5], a[6]
            if sg.startswith("Player-") and sg not in names:
                names[sg] = sn
            if tg.startswith("Player-") and tg not in names:
                names[tg] = tn
            if k == "SPELL_SUMMON" and sg.startswith("Player-"):
                owner[tg] = sg
            block = advanced(a)
            if block is not None:
                ag, og = a[block], a[block + 1]
                if og.startswith("Player-") and ag != og:
                    owner.setdefault(ag, og)
                if ag.startswith(("Creature-", "Vehicle-")):
                    try:
                        hp, mx = int(a[block + 2]), int(a[block + 3])
                    except ValueError:
                        hp = mx = 0
                    if mx > 0 and ag not in owner:
                        nm = sn if ag == sg else tn if ag == tg else ""
                        old = boss_max.get(ag)
                        if not old or mx > old[0]:
                            boss_max[ag] = (mx, nm or (old[1] if old else ""))
                        boss_hp[ag][int(t)] = hp * 100.0 / mx
            if k in DAMAGE and tg.startswith("Player-"):
                d = damage(a)
                if not d:
                    continue
                sid, name, amt, over, hp, mx = d
                srcname = sn if sn not in ("nil", "") else ""
                if k == "SWING_DAMAGE":
                    # v22 logs most melee twice: SWING_DAMAGE, then SWING_DAMAGE_LANDED with the same amount.
                    pending_swing[(sg, tg, amt)] = (t, sid, name, srcname, amt, over, hp, mx)
                    continue
                if k == "SWING_DAMAGE_LANDED":
                    pending_swing.pop((sg, tg, amt), None)
                hit(t, tg, sid, name, srcname, amt, over, hp, mx)
                # an old precursor with no LANDED twin still counts
                if pending_swing:
                    for key in [x for x, v in pending_swing.items() if t - v[0] > 0.1]:
                        v = pending_swing.pop(key)
                        hit(v[0], key[1], v[1], v[2], v[3], v[4], v[5], v[6], v[7])
                continue
            if k == "UNIT_DIED" and tg.startswith("Player-"):
                if a[-1].strip() == "1":  # unconsciousOnDeath: not a real death
                    continue
                i = pidx(tg)
                if i is None:
                    continue
                for key in [x for x in pending_swing if x[1] == tg]:
                    v = pending_swing.pop(key)
                    hit(v[0], tg, v[1], v[2], v[3], v[4], v[5], v[6], v[7])
                last = [h for h in recent[tg] if 0 <= t - h[0] <= RECAP_WINDOW][-RECAP:]
                deaths.append({"t": t, "p": i, "max": maxhp.get(tg, 0), "hits": list(reversed(last))})
                recent[tg] = []
                continue
            if k == "SPELL_CAST_SUCCESS" and sg.startswith("Player-") and len(a) > 9 and a[9].isdigit():
                sid = int(a[9])
                if sid in cds and pidx(sg):
                    casts.append((pidx(sg), sid, t, pidx(tg) or 0))
                continue
            if k == "SPELL_INTERRUPT" and len(a) > 12:
                who = sg if sg.startswith("Player-") else owner.get(sg)
                if who and pidx(who) and a[12].isdigit():
                    ints.append((pidx(who), t, int(a[12]), a[13] if len(a) > 13 else ""))
                    players[who]["ints"] += 1
                continue
            if k == "SPELL_DISPEL" and len(a) > 12:
                who = sg if sg.startswith("Player-") else owner.get(sg)
                if who and pidx(who) and a[12].isdigit():
                    disps.append((pidx(who), t, int(a[12]), 1 if tg.startswith("Player-") else 0))
                    players[who]["disp"] += 1
    for key, v in list(pending_swing.items()):
        hit(v[0], key[1], v[1], v[2], v[3], v[4], v[5], v[6], v[7])
    for g in order:
        players[g]["n"] = short(names.get(g, "Player" + str(players[g]["i"])))
    top = max((v[0] for v in boss_max.values()), default=0)
    # Adds come in copies with one name; a boss is one unit with its name, at least a quarter of the biggest health.
    copies = defaultdict(int)
    for v in boss_max.values():
        copies[v[1]] += 1
    bosses = [g for g, v in boss_max.items() if top and v[0] >= top * 0.25 and copies[v[1]] == 1]
    return {"players": [players[g] for g in order], "spells": spells, "seconds": seconds, "raid": raid,
            "deaths": deaths, "casts": casts, "ints": ints, "disps": disps,
            "bosses": [(boss_max[g][1], boss_hp[g]) for g in bosses], "t0": t0}


# ---------- Encode ----------
def encode(pull, data):
    dur = pull["dur"]
    bosses = data["bosses"]
    ends = []
    for name, hp in bosses:
        if hp:
            ends.append(hp[max(hp)])
    alive = [e for e in ends if e > 0.05]   # a boss that reached 0 while another fought on is not the wipe health
    pct = min(alive or ends) if ends and not pull["kill"] else 0
    spells = sorted(data["spells"].items(), key=lambda kv: -kv[1]["total"])[:MAX_SPELLS]
    keep = {sid for sid, _ in spells}
    srcs = []

    def src_index(name):
        name = clean(name)
        if not name:
            return 0
        if name not in srcs:
            srcs.append(name)
        return srcs.index(name) + 1

    out = []
    head = ["H", b36(pull["enc"]), b36(pull["diff"]), b36(pull["size"]), "1" if pull["kill"] else "0", ds(dur),
            b36(int(data["t0"].timestamp())), b36(round(pct * 10)), b36(pull["n"]), clean(pull["name"])]
    out.append(",".join(head))
    for p in data["players"]:
        out.append(",".join(["P", clean(p["n"]), p["c"], b36(p["spec"]), b36(p["taken"]), b36(p["ints"]),
                             b36(p["disp"])]))
    names = {}
    for sid, s in spells:
        names[sid] = s["name"]
        hits = sorted(s["hits"].items(), key=lambda kv: -kv[1][0])
        out.append(",".join(["S", b36(sid), b36(src_index(s["src"])), b36(s["total"]), b36(s["over"]),
                             ".".join("%s:%s:%s" % (b36(i), b36(h[0]), b36(h[1])) for i, h in hits)]))
        secs = data["seconds"][sid]
        out.append(",".join(["T", b36(sid), ".".join("%s:%s" % (b36(x), b36(max(1, secs[x] // 1000))) for x in sorted(secs))]))
    last = int(dur) + 1
    out.append(",".join(["R", ".".join(b36(data["raid"].get(x, 0) // 1000) for x in range(last))]))
    for d in data["deaths"]:
        hits = []
        for (t, sid, name, amt, over, hp, src) in d["hits"]:
            names.setdefault(sid, name)
            hits.append("%s:%s:%s:%s:%s:%s" % (ds(max(0, d["t"] - t)), b36(sid), b36(amt), b36(max(0, over)),
                                               b36(hp) if hp is not None and hp >= 0 else "", b36(src_index(src))))
        out.append(",".join(["D", ds(d["t"]), b36(d["p"]), b36(d["max"]), ".".join(hits)]))
    for (p, sid, t, target) in data["casts"]:
        out.append(",".join(["C", b36(p), b36(sid), ds(t), b36(target)]))
    for (p, t, sid, name) in data["ints"]:
        if not names.get(sid):
            names[sid] = name
        out.append(",".join(["I", b36(p), ds(t), b36(sid)]))
    for (p, t, sid, friendly) in data["disps"]:
        out.append(",".join(["X", b36(p), ds(t), b36(sid), str(friendly)]))
    for name, hp in data["bosses"]:
        if hp:
            vals = []
            for x in range(0, last, 2):
                v = hp.get(x, hp.get(x + 1))
                vals.append(b36(round(v * 10)) if v is not None else "")
            out.append(",".join(["B", clean(name), ".".join(vals)]))
    out.append(",".join(["N"] + ["%s:%s" % (b36(sid), clean(n)) for sid, n in names.items() if n and sid]))
    out.append(",".join(["W"] + srcs))
    return "~".join(out)


def check(s):
    return b36(sum(s.encode("utf-8")) % (36 ** 4))


def parts(body, key):
    # A part never starts or ends with a space: paste boxes and the addon trim those.
    chunks, i = [], 0
    while i < len(body):
        j = min(len(body), i + PART)
        while j < len(body) and j > i + 1 and (body[j - 1] == " " or body[j] == " "):
            j -= 1
        chunks.append(body[i:j])
        i = j
    chunks = chunks or [""]
    n = len(chunks)
    return ["%s/%s/%d/%d/%s/%s" % (VERSION, key, i + 1, n, check(c), c) for i, c in enumerate(chunks)]


# ---------- Finding World of Warcraft and its logs ----------
def registry_installs():
    """InstallPath from the Blizzard registry entry, when there is one (Windows only, never required)."""
    found = []
    try:
        import winreg
    except ImportError:
        return found
    for key in (r"SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft",
                r"SOFTWARE\Blizzard Entertainment\World of Warcraft"):
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key) as k:
                found.append(winreg.QueryValueEx(k, "InstallPath")[0])
        except OSError:
            pass
    return found


def wow_root(path):
    """Accept the install folder, its _retail_ folder or its Logs folder; return the install folder."""
    path = os.path.normpath(path.strip().strip('"'))
    low = os.path.basename(path).lower()
    if low == "raideriologsarchive":
        path = os.path.dirname(path)
        low = os.path.basename(path).lower()
    if low == "logs":
        path = os.path.dirname(path)
        low = os.path.basename(path).lower()
    if low == "_retail_":
        path = os.path.dirname(path)
    return path


def wow_roots(override=None):
    if override:
        return [wow_root(override)]
    if os.environ.get("WOW_DIR"):
        return [wow_root(os.environ["WOW_DIR"])]
    roots = []
    for cand in registry_installs() + [os.path.join(d + os.sep, i) for d in DRIVES for i in INSTALLS]:
        r = wow_root(cand)
        if r.lower() not in [x.lower() for x in roots]:
            roots.append(r)
    return roots


def log_dirs(roots):
    dirs = []
    for r in roots:
        logs = os.path.join(r, "_retail_", "Logs")
        dirs += [logs, os.path.join(logs, "RaiderIOLogsArchive")]
    return dirs


def newest_log(dirs):
    files = []
    for d in dirs:
        files += glob.glob(os.path.join(glob.escape(d), "WoWCombatLog*.txt"))
    return max(files, key=os.path.getmtime) if files else None


def data_file(name, roots=None):
    """Spell data from the addon: this repo's DynamicPlanner folder, or the installed addon next to the logs."""
    here = os.path.join(ROOT, "DynamicPlanner", "Data", name)
    if os.path.isfile(here):
        return here
    for r in roots if roots is not None else wow_roots(os.environ.get("WOW_DIR")):
        p = os.path.join(r, "_retail_", "Interface", "AddOns", "DynamicPlanner", "Data", name)
        if os.path.isfile(p):
            return p
    sys.exit("Dynamic Planner's Data folder was not found. Install the addon, or run this from the addon's repository.")


def clip(text):
    try:
        subprocess.run(["clip.exe"], input=text.encode("utf-16-le"), check=True, timeout=30)
        return True
    except Exception:
        return False


def last_pull(pulls):
    """The default pick: the last boss pull in the log (pulls shorter than MIN_PULL are already left out)."""
    return pulls[-1]


def summary(p):
    m, s = divmod(int(round(p["dur"])), 60)
    return "%s, %s, %d:%02d, %s (pull %d)" % (p["name"], DIFF.get(p["diff"], str(p["diff"])), m, s,
                                             "kill" if p["kill"] else "wipe", p["n"])


def main():
    ap = argparse.ArgumentParser(
        description="Combat log pulls to Dynamic Planner analyzer paste strings. With no options: the last boss pull "
                    "of the newest log, written to pulls and copied to the clipboard.",
        epilog='Paths with spaces need quotes: py tools\\log2pull.py --wow "C:\\Program Files (x86)\\World of Warcraft"',
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log", nargs="?", help="WoWCombatLog .txt (default: the newest log of every install found)")
    ap.add_argument("--wow", help="World of Warcraft folder to look in (also the WOW_DIR environment variable)")
    ap.add_argument("--pick", action="store_true", help="list the pulls and ask which ones to convert")
    ap.add_argument("--list", action="store_true", help="only list the boss pulls")
    ap.add_argument("--pull", type=int, action="append", help="raw encounter number from the list (repeatable)")
    ap.add_argument("--all-boss", type=int, help="every pull of this encounter ID")
    ap.add_argument("--difficulty", type=int, help="with --all-boss: only this difficulty ID (16 = Mythic)")
    ap.add_argument("--out", default=os.path.join(ROOT if os.path.isdir(os.path.join(ROOT, "DynamicPlanner")) else HERE, "pulls"),
                    help="folder for the .txt files (default: pulls)")
    ap.add_argument("--no-clip", action="store_true", help="do not touch the clipboard")
    args = ap.parse_args()
    if args.log:
        path = args.log
        if not os.path.isfile(path):
            sys.exit("No such file: %s" % path)
    else:
        dirs = log_dirs(wow_roots(args.wow))
        path = newest_log(dirs)
        if not path:
            sys.exit("No WoWCombatLog*.txt found. Looked in:\n  " + "\n  ".join(dirs) +
                     "\nTurn on Advanced Combat Logging and /combatlog in game, or pass the folder: "
                     'py tools\\log2pull.py --wow "D:\\Games\\World of Warcraft"')
    if args.wow:
        os.environ["WOW_DIR"] = args.wow
    print("Reading %s (%.1f MB) ..." % (path, os.path.getsize(path) / 1e6), flush=True)
    pulls = [p for p in index(path) if p["dur"] >= MIN_PULL]
    if not pulls:
        sys.exit("No boss pulls of %d s or more in this log." % MIN_PULL)
    if args.list:
        for p in pulls:
            print(describe(p))
        return
    chosen = []
    if args.pull:
        by = {p["n"]: p for p in pulls}
        for n in args.pull:
            if n not in by:
                sys.exit("Pull %d is not in the list (run with --list)." % n)
            chosen.append(by[n])
    elif args.all_boss:
        chosen = [p for p in pulls if p["enc"] == args.all_boss and (not args.difficulty or p["diff"] == args.difficulty)]
        if not chosen:
            sys.exit("No pulls of encounter %d%s." % (args.all_boss, " on difficulty %d" % args.difficulty if args.difficulty else ""))
    elif args.pick:
        for p in pulls:
            print(describe(p))
        raw = input("Pull number(s), separated by spaces: ").split()
        by = {p["n"]: p for p in pulls}
        chosen = [by[int(x)] for x in raw if x.isdigit() and int(x) in by]
        if not chosen:
            sys.exit("Nothing picked.")
    else:
        chosen = [last_pull(pulls)]
        print("Last pull of %s: %s" % (os.path.basename(path), summary(chosen[0])))
    cds, classes = catalog(), spec_classes()
    os.makedirs(args.out, exist_ok=True)
    everything = []
    for p in chosen:
        data = parse(path, p, cds, classes)
        body = encode(p, data)
        key = b36(int(data["t0"].timestamp()))
        strings = parts(body, key)
        base = os.path.join(args.out, "pull-%d-%d" % (p["n"], p["enc"]))
        with open(base + ".txt", "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(strings) + "\n")
        print("%s: %d players, %d deaths, %d cooldown casts, %d characters in %d part%s -> %s.txt" % (
            describe(p).strip(), len(data["players"]), len(data["deaths"]), len(data["casts"]), len(body),
            len(strings), "" if len(strings) == 1 else "s", base))
        everything.extend(strings)
    if not args.no_clip:
        first = everything[0]
        if len(everything) == 1 and clip(first):
            print("Copied to the clipboard. In game: /dynplan analyzer, Import pull, paste.")
        elif clip(first):
            print("Part 1 of %d copied. Paste it, then copy and paste each next line from the .txt file." % len(everything))
        else:
            print("Clipboard not available; open the .txt file and copy from there.")


if __name__ == "__main__":
    main()
