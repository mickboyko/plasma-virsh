import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Rounded box holding a titled list of VMs
Rectangle {
    id: group
    property string title
    property var domains: []
    required property var host

    visible: domains.length > 0
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: 8
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.15)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: group.title + " (" + group.domains.length + ")"
            font.bold: true
            color: Kirigami.Theme.textColor
        }
        Repeater {
            model: group.domains
            delegate: VmRow {
                required property var modelData
                vm: modelData
                host: group.host
            }
        }
    }
}
