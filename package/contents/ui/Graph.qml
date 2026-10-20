import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Small labelled sparkline. fixedMax > 0 pins the Y scale; otherwise it auto-scales.
ColumnLayout {
    id: g
    property string label
    property string valueText
    property var values: []
    property real fixedMax: 0

    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        QQC2.Label {
            text: g.label
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
        }
        QQC2.Label {
            text: g.valueText
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.textColor
        }
    }

    Canvas {
        id: canvas
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5

        Connections {
            target: g
            function onValuesChanged() { canvas.requestPaint(); }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var v = g.values;
            ctx.fillStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08);
            ctx.fillRect(0, 0, width, height);
            if (v.length < 2)
                return;
            var max = g.fixedMax;
            if (max <= 0) {
                for (var i = 0; i < v.length; i++)
                    max = Math.max(max, v[i]);
                if (max <= 0)
                    max = 1;
            }
            var n = 60; // matches root.historyLength so the graph fills left to right
            var step = width / (n - 1);
            var x0 = width - (v.length - 1) * step;
            ctx.beginPath();
            ctx.moveTo(x0, height);
            for (var j = 0; j < v.length; j++)
                ctx.lineTo(x0 + j * step, height - Math.min(v[j] / max, 1) * (height - 1));
            ctx.lineTo(x0 + (v.length - 1) * step, height);
            ctx.closePath();
            var c = Kirigami.Theme.highlightColor;
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.35);
            ctx.fill();
            ctx.beginPath();
            for (var k = 0; k < v.length; k++) {
                var y = height - Math.min(v[k] / max, 1) * (height - 1);
                if (k === 0)
                    ctx.moveTo(x0, y);
                else
                    ctx.lineTo(x0 + k * step, y);
            }
            ctx.strokeStyle = c;
            ctx.lineWidth = 1;
            ctx.stroke();
        }
    }
}
