import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: row
    required property var vm
    required property var host

    readonly property bool running: vm.state === "running"
    readonly property bool open: host.expanded[vm.name] === true
    readonly property var h: host.history[vm.name]
    readonly property var d: host.details[vm.name]
    readonly property var busy: host.pending[vm.name]

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        QQC2.ToolButton {
            icon.name: row.open ? "arrow-down" : "arrow-right"
            onClicked: row.host.setExpanded(row.vm.name, !row.open)
        }
        QQC2.Label {
            text: row.vm.name
            color: Kirigami.Theme.textColor
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        QQC2.Label {
            text: row.busy ? (row.busy.want === "running" ? i18n("starting…") : i18n("stopping…")) : row.vm.state
            color: row.busy ? Kirigami.Theme.neutralTextColor : row.running ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
        }
        QQC2.BusyIndicator {
            visible: row.busy !== undefined
            running: visible
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium
        }
        QQC2.Button {
            visible: row.busy === undefined
            // virsh has no "stop"; "shutdown" is the graceful equivalent
            text: row.running ? i18n("Stop") : i18n("Start")
            icon.name: row.running ? "media-playback-stop" : "media-playback-start"
            onClicked: row.host.run(row.running ? "shutdown" : "start", row.vm.name)
        }
    }

    ColumnLayout {
        visible: row.open
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 0

            QQC2.Label { text: i18n("IP"); color: Kirigami.Theme.disabledTextColor }
            QQC2.Label {
                text: row.d && row.d.ip ? row.d.ip : "—"
                color: Kirigami.Theme.textColor
                Layout.fillWidth: true
            }
            QQC2.Label { text: i18n("CPUs"); color: Kirigami.Theme.disabledTextColor }
            QQC2.Label {
                text: row.d && row.d.cpus ? row.d.cpus : "—"
                color: Kirigami.Theme.textColor
            }
            QQC2.Label { text: i18n("RAM"); color: Kirigami.Theme.disabledTextColor }
            QQC2.Label {
                text: row.d && row.d.memKiB ? row.host.formatBytes(row.d.memKiB * 1024) : "—"
                color: Kirigami.Theme.textColor
            }
            QQC2.Label { text: i18n("Disk"); color: Kirigami.Theme.disabledTextColor }
            QQC2.Label {
                text: row.d && row.d.disks.length
                    ? row.d.disks.map(function (x) { return x.target + " " + row.host.formatBytes(x.bytes); }).join(", ")
                    : "—"
                color: Kirigami.Theme.textColor
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        GridLayout {
            visible: row.running && row.h !== undefined
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Graph {
                label: i18n("CPU")
                values: row.h ? row.h.cpu : []
                fixedMax: 100
                valueText: values.length ? values[values.length - 1].toFixed(0) + "%" : ""
            }
            Graph {
                label: i18n("Mem")
                values: row.h ? row.h.mem : []
                fixedMax: 100
                valueText: values.length ? values[values.length - 1].toFixed(0) + "%" : ""
            }
            Graph {
                label: i18n("Net")
                values: row.h ? row.h.net : []
                valueText: values.length ? row.host.formatRate(values[values.length - 1]) : ""
            }
            Graph {
                label: i18n("Disk I/O")
                values: row.h ? row.h.disk : []
                valueText: values.length ? row.host.formatRate(values[values.length - 1]) : ""
            }
        }
    }
}
