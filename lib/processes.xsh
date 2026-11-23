"""
What pscpu and psmem share: a list of the running processes, added up by app,
and the table of the biggest ones.

A spell loads it the same way as spellbook:

    from processes import print_top
"""

import os
import re
import sys
import time


# macOS: the system's own ps, by its full path. The ps that nix puts on PATH
# cannot read the memory of most processes. Its "comm" column is the full path
# of the program.
# Linux: "args" is the whole command line. Its first word is the program.
if sys.platform == "darwin":
    PS = ["/bin/ps", "-A", "-o", "pid=,user=,pcpu=,rss=,comm="]
else:
    PS = ["ps", "-A", "-o", "pid=,user=,pcpu=,rss=,args="]


def name_of(program):
    """The plain name of a program: 'firefox' for '/usr/lib/firefox/firefox'."""
    name = os.path.basename(program)
    # NixOS wraps programs and names them like ".firefox-wrapped".
    return re.sub(r"^\.(.+)-wrapped$", r"\1", name)

def app_of(program):
    """The app a program belongs to: 'Google Chrome' for each of Chrome's helpers."""
    inside_an_app = re.search(r"/([^/]+)\.app/", program)
    if inside_an_app:
        return inside_an_app.group(1)
    return name_of(program)

def cpu_right_now(seconds=0.5):
    """Linux only: the share of one core each process used in the last half second.

    ps on Linux reports the average since a process started, which says
    little about now. /proc holds the CPU time used so far, so read it twice.
    """
    def cpu_time_used():
        used = {}
        for pid in filter(str.isdigit, os.listdir("/proc")):
            try:
                with open(f"/proc/{pid}/stat") as stat:
                    fields = stat.read().rsplit(")", 1)[1].split()
                used[int(pid)] = int(fields[11]) + int(fields[12])
            except (OSError, IndexError, ValueError):
                pass  # the process ended in the meantime
        return used

    before = cpu_time_used()
    time.sleep(seconds)
    after = cpu_time_used()

    ticks_per_second = os.sysconf("SC_CLK_TCK")
    return {
        pid: (ticks - before.get(pid, ticks)) / ticks_per_second / seconds * 100
        for pid, ticks in after.items()
    }

def processes():
    """Every running process, as a dict with pid, user, cpu, mem (in KB), name and app."""
    measured = cpu_right_now() if sys.platform == "linux" else {}

    found = []
    for line in $(@(PS)).splitlines():
        fields = line.split(None, 4)
        if len(fields) < 5:
            continue
        pid, user, cpu, mem, program = fields
        if int(pid) == os.getpid():
            continue  # this spell itself is not interesting
        if sys.platform != "darwin":
            program = program.split()[0]

        found.append({
            "pid": int(pid),
            "user": user,
            "cpu": measured.get(int(pid), float(cpu)),
            "mem": int(mem),
            "name": name_of(program),
            "app": app_of(program),
        })
    return found

def by_app(found):
    """One entry per app, with the CPU and memory of its processes added up."""
    apps = {}
    for process in found:
        app = apps.setdefault(process["app"], {"app": process["app"], "cpu": 0.0, "mem": 0, "count": 0})
        app["cpu"] += process["cpu"]
        app["mem"] += process["mem"]
        app["count"] += 1
    return list(apps.values())

def size(kilobytes):
    megabytes = kilobytes / 1024
    if megabytes >= 1000:
        return f"{megabytes / 1024:.1f} GB"
    return f"{megabytes:.0f} MB"

def print_top(sort_by, count, per_process):
    """Print the count biggest apps, or processes, by "cpu" or "mem"."""
    rows = processes() if per_process else by_app(processes())
    rows.sort(key=lambda row: row[sort_by], reverse=True)

    # The column that the lines are sorted by comes first.
    columns = ("cpu", "mem") if sort_by == "cpu" else ("mem", "cpu")
    heads = "  ".join(f"{column.upper():>7}" for column in columns)

    def numbers(row):
        shown = {"cpu": f"{row['cpu']:>6.1f}%", "mem": f"{size(row['mem']):>7}"}
        return "  ".join(shown[column] for column in columns)

    if per_process:
        print(f"{heads}  {'PID':>6}  {'USER':<10}  NAME")
        for row in rows[:count]:
            print(f"{numbers(row)}  {row['pid']:>6}  {row['user'][:10]:<10}  {row['name']}")
    else:
        print(f"{heads}  {'PROCS':>5}  APP")
        for row in rows[:count]:
            print(f"{numbers(row)}  {row['count']:>5}  {row['app']}")
