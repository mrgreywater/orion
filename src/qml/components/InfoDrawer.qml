import QtQuick 2.5
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import QtQuick.Controls.Material 2.1
import app.orion 1.0
import "../util.js" as Util

SidePanel {
    id: root
    property var item: undefined
    property bool labelsVisible: width >= 400
    property int textStyle: Text.Sunken
    dim: false
    modal: false
    Material.theme: Material.Dark
    Material.foreground: "white"
    closePolicy: Popup.CloseOnEscape
    edge: Qt.BottomEdge

    height: 200


    function show(channelItem) {
        item = Util.copyChannel(channelItem);

        bgImage.source = ""
        logoImg.source = ""
        title.text = "N/A"
        description.text = "N/A"
        viewerCount.text = "N/A"

        if (item) {
            bgImage.source = item.preview || ""
            logoImg.source = item.logo || ""
            title.text = "<b>" + item.title + "</b>"
            if (item.game) title.text += " playing " + item.game
            viewerCount.visible = item.viewers >= 0
            viewerCount.text = item.viewers + " viewers"
            description.text = item.info
        }

        open()
    }

    Image {
        z: -1
        id: bgImage
        fillMode: Image.PreserveAspectCrop
        anchors.fill: parent
        Rectangle {
            id: bg
            color: Material.background.hslLightness < 0.5 ? "black" : "white"
            opacity:  0.6
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent"}
                GradientStop { position: 0.8; color: bg.color }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 5

        RoundImage {
            id: logoImg
            visible: labelsVisible
            height: parent.height - 60
            width: height
            Layout.leftMargin: 10
            border {
                color: Material.foreground
                width: 0
            }
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.maximumWidth: 500

            Label {
                id: title
                Layout.fillWidth: true
                font.pointSize: 12
                fontSizeMode: Text.Fit
                wrapMode: Text.WordWrap
                style: textStyle
            }

            Label {
                id: viewerCount
                Layout.fillWidth: true
                font.pointSize: 12
                fontSizeMode: Text.Fit
                wrapMode: Text.WordWrap
                style: textStyle
            }

            Label {
                id: description
                Layout.fillWidth: true
                font.pointSize: 10
                fontSizeMode: Text.Fit
                wrapMode: Text.WordWrap
                style: textStyle
            }
        }

        ColumnLayout {
            //flow: Flow.TopToBottom
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                IconButtonFlat {
                    id: watchBtn
                    font.pointSize: 20
                    text: "\ue038"
                    padding: 0
                    flat: false
                    onClicked: {
                        if (item) {
                            vodsView.search(item)
                            playerView.getStreams(item)
                        }
                        close()
                    }
                }
                Label {
                    visible: labelsVisible
                    text: "Watch"
                    style: textStyle
                }
            }

            RowLayout {
                IconButtonFlat {
                    id: favoriteBtn
                    font.pointSize: 20
                    padding: 0
                    text: "\ue87d"
                    highlighted: item ? item.favourite : false
                    flat: false
                    onClicked: {
                        if (item) {
                            if (item.favourite === false)
                                app.addToFavourites(item, function() {
                                    item = item
                                })
                            else {
                                app.removeFromFavourites(item, function() {
                                    item = item
                                })
                            }
                        }
                    }
                }
                Label {
                    visible: labelsVisible
                    text: item && !item.favourite ? "Follow" : "Unfollow"
                    style: textStyle
                }
            }

            RowLayout {

                IconButtonFlat {
                    id: vodBtn
                    font.pointSize: 20
                    padding: 0
                    text: "\ue04a"
                    flat: false
                    onClicked: {
                        if (item) {
                            vodsView.search(item)
                        }
                        close()
                    }
                }
                Label {
                    visible: labelsVisible
                    text: "Videos"
                    style: textStyle
                }
            }
        }
    }
}
