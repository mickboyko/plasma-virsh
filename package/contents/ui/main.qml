import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    readonly property string listCmd: "virsh list --all"
    property var domains: []
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
            var m = lines[i].match(/^\s*(\S+)\s+(\S+)\s+(.+?)\s*$/);
            if (!m || m[1] === "Id" || /^-+$/.test(m[1]))
                continue;
            result.push({ name: m[2], state: m[3] });
        }
        return result;
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: [root.listCmd]
        interval: 5000

        onNewData: (sourceName, data) => {
            if (sourceName === root.listCmd) {
                if (data["exit code"] === 0) {
                    root.error = "";
                    root.domains = root.parseList(data["stdout"]);
                } else {
                    root.error = data["stderr"] || i18n("virsh failed");
                }
            } else {
                disconnectSource(sourceName);
                executable.connectSource(root.listCmd); // refresh now
            }
        }
    }

    function run(action, domain) {
        executable.connectSource("virsh " + action + " '" + domain.replace(/'/g, "") + "'");
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8

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
        Repeater {
            model: root.domains
            delegate: RowLayout {
                required property var modelData
                readonly property bool running: modelData.state === "running"
                Layout.fillWidth: true

                QQC2.Label {
                    text: modelData.name
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                QQC2.Label {
                    text: modelData.state
                    color: running ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                }
                QQC2.Button {
                    // virsh has no "stop"; "shutdown" is the graceful equivalent
                    text: running ? i18n("Stop") : i18n("Start")
                    icon.name: running ? "media-playback-stop" : "media-playback-start"
                    onClicked: root.run(running ? "shutdown" : "start", modelData.name)
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
