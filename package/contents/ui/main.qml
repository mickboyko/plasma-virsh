import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    readonly property string listCmd: "virsh -c qemu:///system list --all"
    readonly property string statsCmd: "virsh -c qemu:///system domstats --list-running --cpu-total --balloon --vcpu --interface --block"
    readonly property int historyLength: 60
    property var domains: []
    property var runningDomains: []
    property var stoppedDomains: []
    property var expanded: ({})
    property var details: ({})
    property var detailSources: ({})
    // name -> { want: "running" | "off", t: start time }; cleared once the poll reflects it
    property var pending: ({})
    property var actionSources: ({})
    readonly property int pendingTimeoutMs: 90000
    // name -> { cpu: [], mem: [], net: [], disk: [] } (cpu/mem in %, net/disk in bytes/s)
    property var history: ({})
    property var lastSample: ({})
    property string error: ""

    // Transparent background; a shadow keeps the theme text colour readable
    // on any wallpaper.
    Plasmoid.backgroundHints: PlasmaCore.Types.ShadowBackground | PlasmaCore.Types.ConfigurableBackground

    preferredRepresentation: fullRepresentation

    // Parse the output of `virsh list --all`:
    //  Id   Name   State
    // ---------------------
    //  1    vm1    running
    //  -    vm2    shut off
    function parseList(out) {
        var result = [];
        var lines = out.split("\n");
        for (var i = 0; i < lines.length; i++) {
            if (/^\s*-{3,}\s*$/.test(lines[i]))
                continue;
            var m = lines[i].match(/^\s*(\S+)\s+(\S+)\s+(.+?)\s*$/);
            if (!m || m[1] === "Id")
                continue;
            result.push({ name: m[2], state: m[3] });
        }
        return result;
    }

    // Parse `virsh domstats` output into { name: { key: number } }
    function parseStats(out) {
        var result = {};
        var cur = null;
        var lines = out.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var d = lines[i].match(/^Domain: '(.*)'\s*$/);
            if (d) {
                cur = result[d[1]] = {};
                continue;
            }
            var kv = lines[i].match(/^\s+(\S+?)=(.*)$/);
            if (cur && kv)
                cur[kv[1]] = Number(kv[2]);
        }
        return result;
    }

    function sumKeys(st, re) {
        var total = 0;
        for (var k in st)
            if (re.test(k))
                total += st[k];
        return total;
    }

    function push(arr, v) {
        var a = arr.concat([v]);
        return a.length > historyLength ? a.slice(a.length - historyLength) : a;
    }

    function updateStats(stats) {
        var now = Date.now();
        var hist = {};
        var last = {};
        for (var name in stats) {
            var st = stats[name];
            var cur = {
                t: now,
                cpu: st["cpu.time"] || 0,
                net: sumKeys(st, /^net\.\d+\.(rx|tx)\.bytes$/),
                disk: sumKeys(st, /^block\.\d+\.(rd|wr)\.bytes$/)
            };
            var h = history[name] || { cpu: [], mem: [], net: [], disk: [] };
            var prev = lastSample[name];
            var memMax = st["balloon.maximum"] || 0;
            var mem = memMax > 0 ? 100 * (st["balloon.current"] || 0) / memMax : 0;
            if (prev && now > prev.t) {
                var dt = (now - prev.t) / 1000;
                var vcpus = st["vcpu.current"] || 1;
                var cpu = 100 * (cur.cpu - prev.cpu) / (dt * 1e9 * vcpus);
                h = {
                    cpu: push(h.cpu, Math.max(0, Math.min(100, cpu))),
                    mem: push(h.mem, mem),
                    net: push(h.net, Math.max(0, (cur.net - prev.net) / dt)),
                    disk: push(h.disk, Math.max(0, (cur.disk - prev.disk) / dt))
                };
            }
            hist[name] = h;
            last[name] = cur;
        }
        history = hist;
        lastSample = last;
    }

    function clearPending(list) {
        var p = Object.assign({}, pending);
        var changed = false;
        var now = Date.now();
        for (var name in p) {
            var dom = list.find(function (d) { return d.name === name; });
            var isRunning = dom && dom.state === "running";
            var done = !dom || (p[name].want === "running") === isRunning;
            if (done || now - p[name].t > pendingTimeoutMs) {
                delete p[name];
                changed = true;
            }
        }
        if (changed)
            pending = p;
    }

    function setDomains(list) {
        clearPending(list);
        var json = JSON.stringify(list);
        if (json === JSON.stringify(domains))
            return;
        domains = list;
        runningDomains = list.filter(function (d) { return d.state === "running"; });
        stoppedDomains = list.filter(function (d) { return d.state !== "running"; });
    }

    function detailsCmd(name) {
        var n = name.replace(/'/g, "");
        var v = "virsh -c qemu:///system";
        return "N='" + n + "'; echo @@info; " + v + " dominfo \"$N\" 2>/dev/null; "
            + "echo @@blk; " + v + " domblkinfo \"$N\" --all 2>/dev/null; "
            + "echo @@ip; L=$(" + v + " domifaddr \"$N\" 2>/dev/null); echo \"$L\"; "
            + "echo \"$L\" | grep -q ipv4 || { echo @@agent; " + v + " domifaddr \"$N\" --source agent 2>/dev/null; }";
    }

    function setExpanded(name, on) {
        var e = Object.assign({}, expanded);
        var cmd = detailsCmd(name);
        if (on) {
            e[name] = true;
            var ds = Object.assign({}, detailSources);
            ds[cmd] = name;
            detailSources = ds;
            executable.connectSource(cmd);
        } else {
            delete e[name];
            executable.disconnectSource(cmd);
        }
        expanded = e;
    }

    // Parse the sections emitted by detailsCmd
    function updateDetails(name, out) {
        var d = { cpus: "", memKiB: 0, disks: [], ip: "" };
        var section = "";
        var lines = out.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            if (l.indexOf("@@") === 0) {
                section = l.substring(2).trim();
                continue;
            }
            var m;
            if (section === "info") {
                if ((m = l.match(/^CPU\(s\):\s+(\d+)/)))
                    d.cpus = m[1];
                else if ((m = l.match(/^Max memory:\s+(\d+)/)))
                    d.memKiB = Number(m[1]);
            } else if (section === "blk") {
                if ((m = l.match(/^\s*(\S+)\s+(\d+)\s+\d+\s+\d+\s*$/)))
                    d.disks.push({ target: m[1], bytes: Number(m[2]) });
            } else if ((section === "ip" || section === "agent") && !d.ip) {
                if ((m = l.match(/\sipv4\s+(\S+?)(\/\d+)?\s*$/)) && m[1].indexOf("127.") !== 0)
                    d.ip = m[1];
            }
        }
        var all = Object.assign({}, details);
        all[name] = d;
        details = all;
    }

    function formatBytes(b) {
        var units = ["B", "KiB", "MiB", "GiB", "TiB"];
        var i = 0;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            i++;
        }
        return (i === 0 || b >= 100 || b === Math.floor(b) ? b.toFixed(0) : b.toFixed(1)) + " " + units[i];
    }

    function formatRate(b) {
        var units = ["B/s", "KiB/s", "MiB/s", "GiB/s"];
        var i = 0;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            i++;
        }
        return b.toFixed(i === 0 ? 0 : 1) + " " + units[i];
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: [root.listCmd, root.statsCmd]
        interval: 5000

        onNewData: (sourceName, data) => {
            if (sourceName === root.listCmd) {
                if (data["exit code"] === 0) {
                    root.error = "";
                    root.setDomains(root.parseList(data["stdout"]));
                } else {
                    root.error = data["stderr"] || i18n("virsh failed");
                }
            } else if (root.detailSources[sourceName] !== undefined) {
                if (data["exit code"] === 0)
                    root.updateDetails(root.detailSources[sourceName], data["stdout"]);
            } else if (sourceName === root.statsCmd) {
                if (data["exit code"] === 0)
                    root.updateStats(root.parseStats(data["stdout"]));
            } else {
                var failed = root.actionSources[sourceName];
                if (data["exit code"] !== 0 && failed !== undefined) {
                    var p = Object.assign({}, root.pending);
                    delete p[failed];
                    root.pending = p;
                    root.error = data["stderr"] || i18n("virsh failed");
                }
                disconnectSource(sourceName);
                executable.connectSource(root.listCmd); // refresh now
            }
        }
    }

    function run(action, domain) {
        var cmd = "virsh -c qemu:///system " + action + " '" + domain.replace(/'/g, "") + "'";
        var p = Object.assign({}, pending);
        p[domain] = { want: action === "start" ? "running" : "off", t: Date.now() };
        pending = p;
        var a = Object.assign({}, actionSources);
        a[cmd] = domain;
        actionSources = a;
        executable.connectSource(cmd);
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 4
            text: i18n("Virtual machines")
            color: Kirigami.Theme.textColor
        }
        QQC2.Label {
            visible: root.error !== ""
            text: root.error
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        VmGroup {
            title: i18n("Running")
            domains: root.runningDomains
            host: root
        }
        VmGroup {
            title: i18n("Stopped")
            domains: root.stoppedDomains
            host: root
        }
        Item { Layout.fillHeight: true }
    }
}
