#!/usr/bin/env python3
"""Alternate original and Jac OpenSpec CLI runs; report medians and check outputs match.

usage: bench.py ORIG_ROOT JAC_ROOT RUNS [filter] [--json out.json]
"""
import json, os, re, shutil, statistics, subprocess, sys, tempfile, time

NODE = "/home/jayanaka/.neojac/0.5.1/lib/node/bin/node"
FIXTURE_SRC = "/home/jayanaka/neojac-deslop/base/OpenSpec/openspec"
BASE = "/tmp/osbench/work"
CHANGE = "add-tool-command-surface-capabilities"

def env_for(home):
    e = {k: v for k, v in os.environ.items() if not k.startswith(("OPENSPEC", "npm_", "VITEST"))}
    e.update(HOME=home, XDG_CONFIG_HOME=home + "/.config", XDG_STATE_HOME=home + "/.state",
             XDG_DATA_HOME=home + "/.data", OPENSPEC_TELEMETRY="0", DO_NOT_TRACK="1",
             OPENSPEC_NO_UPDATE_CHECK="1", NO_COLOR="1", CI="1", TERM="dumb")
    return e

def setup_project(path):
    if os.path.exists(path):
        shutil.rmtree(path)
    os.makedirs(path)
    shutil.copytree(FIXTURE_SRC, path + "/openspec")
    subprocess.run(["git", "init", "-q", path], check=True)

# name -> (args, needs fresh dir)
WORKLOADS = [
    ("--version", ["--version"], None),
    ("--help", ["--help"], None),
    ("list", ["list"], None),
    ("list --specs --json", ["list", "--specs", "--json"], None),
    ("list --all --json", ["list", "--all", "--json"], None),
    ("validate --all --json", ["validate", "--all", "--json"], None),
    ("validate --specs --strict", ["validate", "--specs", "--strict", "--no-interactive"], None),
    ("show spec --json", ["show", "cli-init", "--type", "spec", "--json"], None),
    ("show change --json", ["show", CHANGE, "--type", "change", "--json"], None),
    ("view", ["view"], None),
    ("status --json", ["status", "--change", CHANGE, "--json"], None),
    ("instructions --json", ["instructions", "proposal", "--change", CHANGE, "--json"], None),
    ("schemas --json", ["schemas", "--json"], None),
    ("templates --json", ["templates", "--json"], None),
    ("doctor --json", ["doctor", "--json"], None),
    ("context --json", ["context", "--json"], None),
    ("config list", ["config", "list", "--json"], None),
    ("init --tools all", ["init", "--tools", "all", "--no-animation", "--scope", "project"], "init"),
    ("update", ["update"], "update"),
]

def norm(s, root):
    s = s.replace(root, "<ROOT>")
    s = re.sub(r"/tmp/osbench/work/[a-z]+/run\d+", "<DIR>", s)
    s = re.sub(r"\d{4}-\d\d-\d\dT[\d:.]+Z", "<TS>", s)
    s = re.sub(r"\b\d+(\.\d+)?m?s\b", "<DUR>", s)
    s = re.sub(r"\"durationMs\": \d+", "\"durationMs\": <N>", s)
    return s

def run(impl_root, args, fresh, idx, side):
    home = f"{BASE}/{side}/home"
    os.makedirs(home, exist_ok=True)
    if fresh:
        cwd = f"{BASE}/{side}/run{idx}"
        if os.path.exists(cwd):
            shutil.rmtree(cwd)
        os.makedirs(cwd)
        subprocess.run(["git", "init", "-q", cwd], check=True)
        if fresh == "update":
            subprocess.run([NODE, impl_root + "/bin/openspec.js", "init", "--tools", "all", "--no-animation", "--scope", "project"],
                           cwd=cwd, env=env_for(home), capture_output=True)
    else:
        cwd = f"{BASE}/proj"
    t0 = time.perf_counter()
    p = subprocess.run([NODE, impl_root + "/bin/openspec.js", *args], cwd=cwd, env=env_for(home),
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    dt = time.perf_counter() - t0
    out = norm(p.stdout, impl_root) + "\n--stderr--\n" + norm(p.stderr, impl_root) + f"\n--exit {p.returncode}"
    if fresh:
        # also fingerprint the files written
        files = []
        for dp, dn, fn in os.walk(cwd):
            if ".git" in dp.split(os.sep):
                continue
            for f in fn:
                fp = os.path.join(dp, f)
                with open(fp, "rb") as fh:
                    files.append((os.path.relpath(fp, cwd), fh.read()))
        files.sort()
        import hashlib
        h = hashlib.sha256(repr(files).encode()).hexdigest()[:16]
        out += f"\n--files {len(files)} {h}"
    return dt, out

def loadavg():
    return open("/proc/loadavg").read().split()[:3]

def main():
    jidx = sys.argv.index("--json") + 1 if "--json" in sys.argv else -1
    roots = [a for i, a in enumerate(sys.argv) if i > 0 and i != jidx and a.startswith("/")]
    rest = [a for a in sys.argv[1:] if not a.startswith("/") and a != "--json"]
    runs = int(rest[0])
    flt = rest[1] if len(rest) > 1 and not rest[1].startswith("--") else None
    jout = sys.argv[sys.argv.index("--json") + 1] if "--json" in sys.argv else None
    names = ["orig", "jac-before", "jac-after"][:len(roots)] if len(roots) <= 3 else [f"r{i}" for i in range(len(roots))]
    os.makedirs(BASE, exist_ok=True)
    setup_project(f"{BASE}/proj")
    results = []
    print(f"load at start: {loadavg()}  nproc={os.cpu_count()}")
    print(f"{'workload':28} " + " ".join(f"{n+' ms':>13}" for n in names) + "  same")
    for name, args, fresh in WORKLOADS:
        if flt and not re.search(flt, name):
            continue
        times = [[] for _ in roots]; outs = [set() for _ in roots]
        for k, r in enumerate(roots):
            run(r, args, fresh, 999, f"s{k}")
        for i in range(runs):
            order = list(range(len(roots)))
            order = order[i % len(order):] + order[:i % len(order)]
            for k in order:
                dt, out = run(roots[k], args, fresh, i, f"s{k}")
                times[k].append(dt); outs[k].add(out)
        meds = [statistics.median(t) * 1000 for t in times]
        same = all(o == outs[0] for o in outs) and len(outs[0]) == 1
        if not same:
            d = f"{BASE}/diff"; os.makedirs(d, exist_ok=True)
            fn = re.sub(r"\W+", "_", name)
            for k, o in enumerate(outs):
                open(f"{d}/{fn}.{names[k]}", "w").write("\n=====\n".join(sorted(o)))
        print(f"{name:28} " + " ".join(f"{m:13.1f}" for m in meds) + f"  {'yes' if same else 'NO'}", flush=True)
        results.append(dict(name=name, medians=dict(zip(names, meds)), same=same, all=dict(zip(names, times)), load=loadavg()))
    print(f"load at end: {loadavg()}")
    if jout:
        json.dump(dict(results=results), open(jout, "w"), indent=1)

main()
