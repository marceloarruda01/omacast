import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
    id: root

    property real iconSize: Style.font.icon
    property color color: Color.foreground
    property string variant: "microphone"

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize

    IconShape {
        shown: root.variant === "microphone"
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M9 5.5a3 3 0 0 1 6 0v5a3 3 0 0 1-6 0z M5.5 11v1a6.5 6.5 0 0 0 13 0v-1 M12 18.5v3 M8.75 21.5h6.5"
            }
        }
    }

    IconShape {
        shown: root.variant === "broadcast"
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M15.4 8.9a4.6 4.6 0 0 1 0 6.2 M18.1 6.4a8.2 8.2 0 0 1 0 11.2 M8.6 8.9a4.6 4.6 0 0 0 0 6.2 M5.9 6.4a8.2 8.2 0 0 0 0 11.2"
            }
        }
        ShapePath {
            fillColor: root.color
            strokeWidth: 0
            PathSvg {
                path: "M10.1 12a1.9 1.9 0 1 0 3.8 0a1.9 1.9 0 1 0-3.8 0"
            }
        }
    }

    IconShape {
        shown: root.variant === "headphones"
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M4 15v-3a8 8 0 0 1 16 0v3 M3 16.3a1.8 1.8 0 0 1 1.8-1.8h.4a1.8 1.8 0 0 1 1.8 1.8v2.4a1.8 1.8 0 0 1-1.8 1.8h-.4A1.8 1.8 0 0 1 3 18.7z M17 16.3a1.8 1.8 0 0 1 1.8-1.8h.4a1.8 1.8 0 0 1 1.8 1.8v2.4a1.8 1.8 0 0 1-1.8 1.8h-.4a1.8 1.8 0 0 1-1.8-1.8z M10.5 15v4 M13.5 14v5"
            }
        }
    }

    component IconShape: Shape {
        property bool shown: false

        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.iconSize / 24
        visible: shown
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
    }
}
