# Green Bay Packers game app. Data: ESPN's unofficial public JSON API (no key).
BASE = "https://site.api.espn.com/apis/site/v2/sports/football/nfl"
ME = "GB"
LW = 112  # width of the always-visible score block on live pages (shortcut: assumes width >= 192)

# ---------- data ----------
def fetch(url, ttl, params = {}):
    r = http.get(url, params = params, ttl_seconds = ttl)
    if r["status_code"] != 200 or r["json"] == None:
        return None
    return r["json"]

def load_game():
    sb = fetch(BASE + "/scoreboard", 120)
    if sb == None:
        return None
    for e in sb.get("events", []):
        for t in e["competitions"][0]["competitors"]:
            if t["team"]["abbreviation"] == ME:
                return fetch(BASE + "/summary", 60, {"event": e["id"]})
    return None

def comp(g):
    return g["header"]["competitions"][0]

def sides(g):
    # returns (me, opponent) competitor dicts
    cs = comp(g)["competitors"]
    if cs[0]["team"]["abbreviation"] == ME:
        return cs[0], cs[1]
    return cs[1], cs[0]

def state(g):
    return comp(g)["status"]["type"]["state"]  # pre | in | post

def status_lines(g):
    s = comp(g)["status"]
    t = s["type"]
    if t["state"] == "pre":
        return "", ""
    if t["state"] == "post":
        return "FINAL", ""
    if t["name"] == "STATUS_HALFTIME":
        return "HALF", ""
    p = s.get("period", 0)
    return ("OT" if p > 4 else "Q" + str(p)), s.get("displayClock", "")

# ---------- drawing helpers ----------
def trunc(c, s, maxw, font):
    for _ in range(len(s)):
        if c.text_width(s, font = font) <= maxw:
            break
        s = s[:-1]
    return s

def say(c, msg, color = "red"):
    c.fill("black")
    c.text(msg, c.width // 2 - c.text_width(msg, font = "7x12") // 2, 10, font = "7x12", color = color)

def last(name):
    return name.split(" ")[-1].upper()

def grid(c, title, entries):
    # entries: list of (text, color); 4 rows of 5x7 text, as many columns as fit
    c.fill("black")
    c.rect(0, 0, 2, c.height - 1, fill = "green")
    c.text(title, 6, 12, font = "5x7", color = "green")
    x0 = 40
    cols = max(1, (c.width - x0) // 110)
    cw = (c.width - x0) // cols
    cap = cols * 4
    if len(entries) > cap:
        entries = entries[:cap - 1] + [("+" + str(len(entries) - cap + 1) + " MORE", "gray")]
    for i in range(len(entries)):
        text, col = entries[i]
        c.text(trunc(c, text, cw - 4, "5x7"), x0 + (i // 4) * cw, 1 + (i % 4) * 8, font = "5x7", color = col)

def score_block(c, g):
    me, op = sides(g)
    c.fill("black")
    for i in range(2):
        t = [me, op][i]
        y = 2 + i * 15
        c.text(t["team"]["abbreviation"], 2, y, font = "8x12", color = "green" if i == 0 else "white")
        c.text(t.get("score", ""), 34, y, font = "8x12", color = "white")
    a, b = status_lines(g)
    c.text(a, 76, 6, font = "5x7", color = "amber")
    c.text(b, 76, 17, font = "5x7", color = "amber")
    c.line(LW - 1, 2, LW - 1, c.height - 3, "midgray")

# ---------- pre-game ----------
def pre_main(c, g):
    me, op = sides(g)
    names = ME + " @ " + op["team"]["abbreviation"] if me["homeAway"] == "away" else op["team"]["abbreviation"] + " @ " + ME
    pc = g.get("pickcenter", [])
    line = pc[0].get("details", "NO LINE") if pc else "NO LINE"
    ou = pc[0].get("overUnder") if pc else None
    c.fill("black")
    c.text(names, 4, 1, font = "10x15", color = "green")
    c.text(comp(g)["status"]["type"]["shortDetail"].upper(), 4, 21, font = "5x7", color = "white")
    x = c.width // 2
    c.text("LINE", x, 3, font = "5x7", color = "gray")
    c.text(line.upper(), x, 14, font = "10x15", color = "amber")
    if ou:
        c.text("O/U " + str(ou), x + 120, 18, font = "5x7", color = "white")

SEV = {"Out": 0, "Injured Reserve": 1, "Doubtful": 2, "Questionable": 3}
TAG = {"Out": "OUT", "Injured Reserve": "IR", "Doubtful": "D", "Questionable": "Q"}
COL = {"Out": "red", "Injured Reserve": "red", "Doubtful": "amber", "Questionable": "yellow"}

def sev(i):
    return SEV.get(i["status"], 9)

def pre_injuries(c, g):
    mine = []
    for t in g.get("injuries", []):
        if t["team"]["abbreviation"] == ME:
            mine = sorted(t["injuries"], key = sev)
    if not mine:
        grid(c, "INJ", [("NONE REPORTED", "green")])
        return
    grid(c, "INJ", [(last(i["athlete"]["displayName"]) + " " + TAG.get(i["status"], i["status"][:3].upper()), COL.get(i["status"], "white")) for i in mine])

# ---------- live / final ----------
def live_main(c, g):
    cs = comp(g)["competitors"]  # ESPN lists home first; show away on the left like a TV bug
    away = cs[0] if cs[0]["homeAway"] == "away" else cs[1]
    home = cs[1] if away == cs[0] else cs[0]
    cx = c.width // 2
    c.fill("black")
    for side in [(away, cx - 150, cx - 110), (home, cx + 80, cx + 25)]:
        t, ax, sx = side
        c.text(t["team"]["abbreviation"], ax, 6, font = "16x20", color = "green" if t["team"]["abbreviation"] == ME else "white")
        c.text(t.get("score", "0"), sx, 6, font = "16x20", color = "white")
    a, b = status_lines(g)
    c.text(a, cx - c.text_width(a, font = "5x7") // 2, 7, font = "5x7", color = "amber")
    c.text(b, cx - c.text_width(b, font = "5x7") // 2, 18, font = "5x7", color = "amber")

STATS = [("TOT YDS", "Total Yards"), ("PASS", "Passing"), ("RUSH", "Rushing"), ("1ST DN", "1st Downs"), ("TO", "Turnovers"), ("TOP", "Possession"), ("3RD DN", "3rd down efficiency"), ("PEN", "Penalties")]

def live_stats(c, g):
    score_block(c, g)
    vals = {}
    for t in g["boxscore"]["teams"]:
        vals[t["team"]["abbreviation"]] = {s["label"]: s["displayValue"] for s in t["statistics"]}
    me, op = sides(g)
    mine, theirs = vals.get(ME, {}), vals.get(op["team"]["abbreviation"], {})
    rows = [(n, mine[k], theirs.get(k, "-")) for n, k in STATS if k in mine]
    if not rows:
        c.text("NO STATS YET", LW + 8, 12, font = "5x7", color = "gray")
        return
    cw = (c.width - LW - 4) // 2
    for i in range(min(len(rows), 8)):
        n, a, b = rows[i]
        x = LW + 6 + (i // 4) * cw
        y = 1 + (i % 4) * 8
        c.text(n, x, y, font = "5x7", color = "gray")
        c.text(a, x + 56, y, font = "5x7", color = "green")
        c.text(b, x + 94, y, font = "5x7", color = "white")

def live_leaders(c, g, cats):
    score_block(c, g)
    me, op = sides(g)
    by = {t["team"]["abbreviation"]: {l["name"]: l for l in t["leaders"]} for t in g.get("leaders", [])}
    cw = (c.width - LW - 4) // 2
    rh = 30 // len(cats)
    for r in range(len(cats)):
        key, suffix = cats[r]
        for j in range(2):
            ab = [ME, op["team"]["abbreviation"]][j]
            l = by.get(ab, {}).get(key)
            if l == None or not l["leaders"]:
                continue
            a = l["leaders"][0]
            dv = ", ".join(l["leaders"][0]["displayValue"].split(", ")[:3])  # drop INT so it fits
            s = a["athlete"]["shortName"] + " " + dv.replace(",", "").replace(" YDS", "Y").replace(" CAR", "C").replace(" TD", "TD") + suffix
            c.text(trunc(c, s.upper(), cw - 4, "4x5"), LW + 6 + j * cw, 1 + r * rh + (rh - 5) // 2, font = "4x5", color = "green" if j == 0 else "white")

# ---------- pages ----------
def route(c, g, pre_fn, live_fn):
    if g == None:
        say(c, "NO PACKERS GAME")
    elif state(g) == "pre":
        pre_fn(c, g)
    else:
        live_fn(c, g)

def main(c, ctx):
    g = load_game()
    route(c, g, pre_main, live_main)

def second(c, ctx):
    route(c, load_game(), pre_injuries, live_stats)

def third(c, ctx):
    g = load_game()
    if g == None:
        say(c, "NO PACKERS GAME")
    else:
        live_leaders(c, g, [("passingYards", ""), ("rushingYards", ""), ("receivingYards", ""), ("sacks", " SCK"), ("totalTackles", " TKL")])
