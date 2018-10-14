import QtQuick 2.5
import "../util.js" as Util

Item {
    id: root
    property string source
    property real from: 0
    property real to: d.duration
    property real value: 0
    property int fillMode: Image.PreserveAspectFit

    implicitWidth: image.implicitWidth
    implicitHeight: image.implicitHeight

    QtObject {
        id: d

        property string baseUrl

        property int column: 0
        property int row: 0
        property int page: 0
        property int width: 0
        property int height: 0
        property real duration: 0
        property var images: []

        property var info

        function updateImage() {
            if (!info) return
            var i = Math.min(info.count - 1, Math.round((value - root.from) / (root.to - root.from) * info.count))
            var fullRow = Math.floor(i / info.cols)
            column = i % info.cols
            page = Math.floor(fullRow / info.rows)
            row = fullRow % info.rows
        }
    }

    Connections {
        target: root
        onSourceChanged: {
            d.duration = 0
            d.width = 0
            d.height = 0
            d.images = []
            d.info = undefined
            if (!source) return
            d.baseUrl = source.substring(0, source.lastIndexOf("/"))
            Util.requestJSON(source, function(resp) {
                d.info = resp[0]
                for(var i = 1; i < resp.length; i++) {
                    if (resp[i].width > d.info.width) {
                        d.info = resp[i]
                    }
                }
                d.duration = d.info.count * d.info.interval
                d.width = d.info.width
                d.height = d.info.height
                d.images = d.info.images
                d.updateImage()
            })
        }
        onFromChanged: d.updateImage()
        onToChanged: d.updateImage()
        onValueChanged: d.updateImage()
    }

    Rectangle {
        id: image
        clip: true
        visible: d.images.length > 0
        color: "transparent"

        Repeater {
            model: d.images
            delegate: Image {
                x: -d.width * d.column
                y: -d.height * d.row
                source: d.baseUrl + "/" + modelData;
                asynchronous: true;
                visible: d.page === index
            }
        }

        implicitWidth: d.width
        implicitHeight: d.height

        property real fitToWidth: root.fillMode === Image.PreserveAspectFit ? image.implicitWidth * root.height > root.width * image.implicitHeight : true
        property real fitToHeight: root.fillMode === Image.PreserveAspectFit ? !fitToWidth : true

        property real paintedWidth: fitToWidth ? root.width : paintedHeight / image.implicitHeight * image.implicitWidth
        property real paintedHeight: fitToHeight ? root.height : paintedWidth / image.implicitWidth * image.implicitHeight

        x: (root.width - paintedWidth) / 2
        y: (root.height - paintedHeight) / 2

        transform: Scale {
            xScale: image.paintedWidth / image.implicitWidth
            yScale: image.paintedHeight / image.implicitHeight
        }
    }
}
