/*
 * Copyright © 2015-2016 Antti Lamminsalo
 *
 * This file is part of Orion.
 *
 * Orion is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU General Public License
 * along with Orion.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.5
import QtQuick.Controls 2.1
import QtQuick.Controls.Material 2.1
import QtQuick.Layouts 1.1
import "components"
import "util.js" as Util

import app.orion 1.0

Page {
    id: root

    property int duration: -1
    property var currentChannel
    property var streamMap
    property bool isVod: false
    property bool streamOnline: true
    property string curVodId
    property int lastSetPosition
    property bool headersVisible: true

    onHeadersVisibleChanged: {
        if (root.visible) {
            pArea.hoverEnabled = false
            topbar.visible = headersVisible
            disableTimer.restart()
        }
    }

    Material.theme: rootWindow.Material.theme

    //Renderer interface
    property alias renderer: loader.item


    //Fix minimode header bar
    clip: true

    Connections {
        target: ChannelManager

        onAddedChannel: {
            console.log("Added channel")
            if (currentChannel && currentChannel._id == chanid){
                currentChannel.favourite = true
                favBtn.update()
            }
        }

        onDeletedChannel: {
            console.log("Deleted channel")
            if (currentChannel && currentChannel._id == chanid){
                currentChannel.favourite = false
                favBtn.update()
            }
        }

        onFoundPlaybackStream: {
            loadStreams(streams)
        }
    }

    Connections {
        target: Network

        onNetworkAccessChanged: {
            if (up && currentChannel && !renderer.status !== "PAUSED") {
                //console.log("Network up. Resuming playback...")
                loadAndPlay()
            }
        }

        onStreamGetOperationFinished: {
            //console.log("Received stream status", channelId, currentChannel._id, online)
            if (channelId === currentChannel._id) {
                if (online && !root.streamOnline) {
                    console.log("Stream back online, resuming playback")
                    loadAndPlay()
                }
                root.streamOnline = online
            }
        }

        onError: {
            switch (error) {

            case "token_error":
            case "playlist_error":
                //Display messagetrue
                setHeaderText("Error getting stream")
                break;

            default:
                break;
            }
        }
    }

    Timer {
        //Polls channel when stream goes down
        id: pollTimer
        interval: 4000
        repeat: true
        onTriggered: {
            if (currentChannel && currentChannel._id)
                Network.getStream(currentChannel._id)
        }
    }


    function loadAndPlay(){
        var description = setWatchingTitle();

        var start = !isVod ? -1 : seekBar.value

        var url = streamMap[Settings.quality]

        console.debug("Loading: ", url)

        renderer.load(url, start, description)
    }

    function getStreams(channel, vod, startPos){
        getChannel(channel, vod, true, startPos);
    }

    function getChat(channel) {
        getChannel(channel, null, false, 0);
    }

    function getChannel(channel, vod, wantVideo, startPos){

        if (!channel){
            return
        }

        renderer.stop()

        if (wantVideo) {
            if (!vod || typeof vod === "undefined") {
                ChannelManager.findPlaybackStream(channel.name)
                isVod = false

                duration = -1
            }
            else {
                VodManager.getBroadcasts(vod._id)
                isVod = true
                root.curVodId = vod._id
                root.lastSetPosition = startPos

                duration = vod.duration

                console.log("Setting up VOD, duration " + vod.duration)

                seekBar.value = startPos
            }
        } else {
            isVod = false;
        }

        currentChannel = {
            "_id": channel._id,
            "name": channel.name,
            "game": isVod ? vod.game : channel.game,
            "title": isVod ? vod.title : channel.title,
            "online": channel.online,
            "favourite": channel.favourite || ChannelManager.containsFavourite(channel._id),
            "viewers": channel.viewers,
            "logo": channel.logo,
            "preview": channel.preview,
            "seekPreviews": isVod ? vod.seekPreviews : "",
        }

        favBtn.update()
        setWatchingTitle()

        if (isVod) {
            var startEpochTime = (new Date(vod.createdAt)).getTime() / 1000.0;

            console.log("typeof vod._id is", typeof(vod._id))

            if (vod._id.charAt(0) !== "v") {
                console.log("unknown vod id format in", vod._id);
            } else {
                var vodIdNum = parseInt(vod._id.substring(1));
                console.log("replaying chat for vod", vodIdNum, "starting at", startEpochTime);
                chat.replayChat(currentChannel.name, currentChannel._id, vodIdNum, startEpochTime, startPos);
            }
        } else {
            chat.joinChannel(currentChannel.name, currentChannel._id);
        }

        pollTimer.restart()

        requestSelectionChange(4)
    }

    function setHeaderText(text) {
        title.text = text
    }

    function setWatchingTitle(){
	var description = ""
	if (currentChannel) {
	  description = currentChannel.title + (isVod ? ("\r\n" + currentChannel.name) : "")
		  + (currentChannel.game ? " playing " + currentChannel.game : "")
		  + (isVod ? " (VOD)" : "");
	  setHeaderText(description);
	}
	return description;
    }

    function loadStreams(streams) {
        var sourceNames = []
        for (var k in streams) {
            sourceNames.splice(0, 0, k) //revert order
        }

        streamMap = streams
        sourcesBox.model = sourceNames

        sourcesBox.selectItem(Settings.quality);
        loadAndPlay()
    }

    function seekTo(position) {
        console.log("Seeking to", position, duration)
        if (isVod){
            chat.playerSeek(position)
            renderer.seekTo(position)
        }
    }

    function reloadStream() {
        renderer.stop()
        loadAndPlay()
    }

    Connections {
        target: VodManager
        onStreamsGetFinished: {
            loadStreams(items)
        }
    }

    Connections {
        target: rootWindow
        onClosing: {
            renderer.stop()
        }
    }

    Connections {
        target: renderer

        onPositionChanged: {
            var newPos = renderer.position;
            chat.playerPositionUpdate(newPos);
            if (root.isVod) {
                if (Math.abs(newPos - root.lastSetPosition) > 10) {
                    root.lastSetPosition = newPos;
                    VodManager.setVodLastPlaybackPosition(root.currentChannel.name, root.curVodId, newPos);
                }
            }
            if (!seekBar.pressed) {
                seekBar.value = newPos
            }
        }

        onPlayingResumed: {
            setWatchingTitle()
        }

        onPlayingPaused: {
            setHeaderText("Paused")
        }

        onPlayingStopped: {
            setHeaderText("Playback stopped")
        }

        onStatusChanged: {
            PowerManager.screensaver = (renderer.status !== "PLAYING")
        }
    }

    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: {
            renderer.togglePause()
            clickRect.run()
            pArea.refreshHeaders()
        }
    }

    Repeater {
        model: ["0", "F5"]
        delegate: Item { Shortcut {
            sequence: modelData
            context: Qt.ApplicationShortcut
            onActivated: {
                reloadStream()
                clickRect.show("\ue5d5")
            }
        } }
    }

    Shortcut {
        sequence: "f"
        context: Qt.ApplicationShortcut
        onActivated: {
            appFullScreen = !appFullScreen
        }
    }

    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        onActivated: {
            appFullScreen = false
        }
    }

    Shortcut {
        sequence: "m"
        context: Qt.ApplicationShortcut
        onActivated: {
            volumeBtn.toggleMute()
            clickRect.show(volumeSlider.value > 0 ? "\ue050" : "\ue04f")
        }
    }

    Shortcut {
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (volumeSlider.value < volumeSlider.to) {
                volumeSlider.value += 5
                clickRect.show("\ue050")
            }
        }
    }

    Shortcut {
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (volumeSlider.value > volumeSlider.from) {
                volumeSlider.value -= 5
                clickRect.show("\ue04d")
            }
        }
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!isVod || seekBar.pressed) return
            seekBar.seek(seekBar.value + 5)
            var totalSeek = seekBar.value - renderer.position
            clickRect.show((totalSeek > 0 ? "+" : "") + totalSeek + "s")
        }
    }

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!isVod || seekBar.pressed) return
            seekBar.seek(seekBar.value - 5)
            var totalSeek = seekBar.value - renderer.position
            clickRect.show((totalSeek > 0 ? "+" : "") + totalSeek + "s")
        }
    }

    Item {
        id: playerArea
        anchors.fill: parent

        Loader {
            id: loader
            anchors.fill: parent

            source: {
                switch (Settings.appPlayerBackend()) {
                case "mpv":
                    return "MpvBackend.qml";

                case "qtav":
                    return "QtAVBackend.qml";

                case "multimedia":
                default:
                    return "MultimediaBackend.qml";
                }
            }

            onLoaded: {
                console.log("Loaded renderer")
            }
        }

        SeekPreview {
            id: preview
            anchors.fill: parent
            visible: opacity > 0
            opacity: 0
            Behavior on opacity { PropertyAnimation { easing: Easing.InOutCubic } }

            Connections {
                target: seekBar
                onValueChanged: preview.value = seekBar.value
                onPressedChanged: {
                    if (seekBar.pressed) {
                        preview.opacity = 1
                        //todo: stop player while seeking
                    }
                }
            }
            Connections {
                target: renderer
                onStatusChanged: {
                    if (preview.visible && !seekBar.pressed && renderer.status !== "BUFFERING") {
                        Util.setTimeout(function() {
                            if (!seekBar.pressed) preview.opacity = 0
                        }, 100)
                    }
                }
            }
            Connections {
                target: root
                onCurrentChannelChanged: preview.source = currentChannel.seekPreviews
                onDurationChanged: preview.to = duration
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: renderer.status === "BUFFERING"
        }
    }

    MouseArea {
        id: pArea
        anchors.fill: playerArea

        function refreshHeaders(){
            if (!hideTimer.running && !root.headersVisible)
                root.headersVisible = true
            hideTimer.restart()
        }
	
        Timer {
            id: disableTimer
            interval: 200
            running: false
            onTriggered:{
                pArea.hoverEnabled = true
            }
        }

        onVisibleChanged: refreshHeaders()
        onPositionChanged: refreshHeaders()

        Rectangle {
            id: clickRect
            anchors.centerIn: parent
            width: 0
            height: width
            radius: height / 2
            opacity: 0

            Label {
                id: clickRectIcon
                text: ""
                anchors.centerIn: parent
                font.family: /^[\x00-\x7F]*$/.test(text) ? "Helvetica" : "Material Icons"
                font.pointSize: parent.width * 0.5 / text.length
            }

            ParallelAnimation {
                id: _anim
                running: false

                onStopped: {
                    clickRect.opacity = 0
                }

                NumberAnimation {
                    target: clickRect
                    property: "width"
                    from: pArea.width * 0.1
                    to: pArea.width * 0.6
                    duration: 1500
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: clickRect
                    property: "opacity"
                    from: 0.5
                    to: 0
                    duration: 666
                    easing.type: Easing.OutCubic
                }
            }

            function show(text) {
                clickRectIcon.text = text
               _anim.restart()
            }

            function run() {
                 show(renderer.status !== "PLAYING" ? "\ue037" : "\ue034")
            }

            function abort() {
                _anim.stop()
            }
        }

        onClicked: {
            clickRect.run()
            clickTimer.restart()
            refreshHeaders()
        }
        onDoubleClicked: {
            if (!isMobile()) {
                clickTimer.stop()
                clickRect.abort();
                appFullScreen = !appFullScreen
            }
        }
        hoverEnabled: true
        propagateComposedEvents: true
        cursorShape: headersVisible ? Qt.ArrowCursor : Qt.BlankCursor

        Timer {
            //Dbl click timer
            id: clickTimer
            interval: 200
            repeat: false
            onTriggered: {
                renderer.togglePause();
            }
        }

        Timer {
            id: hideTimer
            interval: 2000
            running: false
            repeat: false
            onTriggered: {
                if (!root.headersVisible || headerBarArea.containsMouse || bottomBarArea.containsMouse) return

                if (renderer.status === "PAUSED" || renderer.status === "STOPPED") return

                // Bug?: MouseArea doesn't work over Controls
                var controls = [ favBtn, chatBtn, playBtn, resetBtn, volumeBtn, volumeSlider, seekBar, hwaccelBox, sourcesBox, cropBtn, fsBtn];
                for (var i = 0; i < controls.length; i++) {
                    if (controls[i].hovered || controls[i].pressed || controls[i].down)
                        return;
                }

                root.headersVisible = false
            }
        }

        ToolBar {
            id: headerBar
            Material.foreground: rootWindow.Material.foreground
            background: Rectangle {
                color: root.Material.background
                opacity: 0.8
            }

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            clip: true
            height: root.headersVisible ? 55 : 0
            visible: height > 0

            Behavior on height {
                NumberAnimation {
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: headerBarArea
                anchors.fill: parent
                hoverEnabled: true
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 5
                    rightMargin: 5
                }

                Label {
                    id: title
                    font.pointSize: 9
                    Layout.fillWidth: true
                    horizontalAlignment: Qt.AlignHCenter
                    clip: true
                    font.bold: true
                }

                IconButtonFlat {
                    id: favBtn
                    text: "\ue87d"

                    function update() {
                        highlighted = currentChannel.favourite === true
                    }

                    onClicked: {
                        if (currentChannel){
                            if (currentChannel.favourite)
                                ChannelManager.removeFromFavourites(currentChannel._id)
                            else{
                                //console.log(currentChannel)
                                ChannelManager.addToFavourites(currentChannel._id, currentChannel.name,
                                                               currentChannel.title, currentChannel.info,
                                                               currentChannel.logo, currentChannel.preview,
                                                               currentChannel.game, currentChannel.viewers,
                                                               currentChannel.online)
                            }
                        }
                    }
                }

                IconButtonFlat {
                    id: chatBtn
                    visible: !isMobile()
                    onClicked: {
                        if (chatdrawer.position <= 0)
                            chatdrawer.open()
                        else
                            chatdrawer.close()
                    }
                    text: chat.hasUnreadMessages ? "\ue87f" : "\ue0ca"
                }
            }
        }

        ToolBar {
            id: bottomBar
            Material.foreground: rootWindow.Material.foreground
            background: Rectangle {
                color: root.Material.background
                opacity: 0.8
            }

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            clip: false
            height: root.headersVisible ? 55 : 0
            visible: height > 0

            Behavior on height {
                NumberAnimation {
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: bottomBarArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Slider {
                id: seekBar
                from: 0
                to: duration
                visible: isVod && headersVisible
                padding: 0
                hoverEnabled: true
                clip: true

                anchors {
                    verticalCenter: parent.top
                    left: parent.left
                    right: parent.right
                }

                Component.onCompleted: {
                    handle.opacity = 0;
                }

                PropertyAnimation {
                    id: handleAnimation
                    target: seekBar.handle
                    easing.type: Easing.OutQuad
                    property: "opacity"
                    duration: 400
                    running: false
                }

                onHoveredChanged: {
                    var wantedOpacity = hovered || pressed ? 1 : 0;
                    if (handle.opacity === wantedOpacity) return;
                    handleAnimation.to = wantedOpacity;
                    handleAnimation.restart();
                }
                onPressedChanged: {
                    if (!pressed)
                        seekTo(value)
                }

                property real prev: 0
                onValueChanged: {
                    if (seekTimer.running)
                        value = seekTimer.to
                }

                Timer {
                    id: seekTimer
                    interval: 500
                    repeat: false
                    property real to: 0
                    onTriggered: {
                        seekTo(seekBar.value);
                    }
                }

                function seek(val) {
                    seekTimer.to = val
                    value = val
                    seekTimer.restart()
                }

                MouseArea {
                    id: seekBarMouseArea
                    anchors.fill: seekBar
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onClicked: mouse.accepted = false
                    onPressed: mouse.accepted = false
                }

            }

            Rectangle {
                color: root.Material.background
                radius: 5
                implicitHeight: seekTooltip.implicitHeight
                implicitWidth: seekTooltip.implicitWidth

                anchors.bottom: seekBar.top
                x: Math.min(seekBar.width-width-5, Math.max(5, (seekBar.pressed ? (seekBar.handle.x + seekBar.handle.width / 2) : seekBarMouseArea.mouseX) - width / 2))

                visible: opacity > 0
                opacity: (seekBar.hovered || seekBar.pressed) ? 1 : 0
                Behavior on opacity { PropertyAnimation { easing: Easing.InCubic } }

                ColumnLayout {
                    id: seekTooltip
                    anchors.fill: parent
                    spacing: 0

                    function timeAtMouse() {
                        if (seekBar.pressed && seekBar.live) return seekBar.value
                        var seekWidth = seekBar.width - seekBar.handle.width
                        var seekX = seekBarMouseArea.mouseX - seekBar.handle.width / 2
                        seekX = Math.min(seekWidth, Math.max(0, seekX))
                        return seekBar.valueAt(seekX / seekWidth)
                    }

                    SeekPreview {
                        id: seekPreview

                        Layout.topMargin: 5
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5

                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight

                        visible: !seekBar.pressed && implicitWidth > 0

                        Connections {
                            target: seekBar
                            onValueChanged: seekPreview.value = seekTooltip.timeAtMouse()
                        }
                        Connections {
                            target: seekBarMouseArea
                            onPositionChanged: seekPreview.value = seekTooltip.timeAtMouse()
                        }
                        Connections {
                            target: root
                            onCurrentChannelChanged: seekPreview.source = currentChannel.seekPreviews
                            onDurationChanged: seekPressedPreview.to = duration
                        }

                    }

                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        padding: 5
                        text: Util.formatTime(seekTooltip.timeAtMouse())
                    }
                }

            }

            RowLayout {
                anchors {
                    fill: parent
                    rightMargin: 5
                    leftMargin: 5
                }                
                spacing: 0

                IconButtonFlat {
                    id: playBtn
                    text: renderer.status !== "PLAYING" && renderer.status !== "BUFFERING" ? "\ue037" : "\ue034"
                    onClicked: renderer.togglePause()
                }

                IconButtonFlat {
                    id: resetBtn
                    text: "\ue5d5"
                    onClicked: reloadStream()
                }

                IconButtonFlat {
                    id: volumeBtn
                    visible: !isMobile()
                    property real mutedValue: 100.0
                    text: volumeSlider.value > 0 ?
                              (volumeSlider.value > 50 ? "\ue050" : "\ue04d")
                            : "\ue04f"
                    onClicked: {
                        toggleMute()
                    }
                    function toggleMute() {
                        if (volumeSlider.value > 0) {
                            mutedValue = volumeSlider.value
                            volumeSlider.value = 0
                        } else {
                            volumeSlider.value = mutedValue
                        }
                    }
                }

                Slider {
                    id: volumeSlider
                    from: 0
                    to: 100
                    width: 0
                    opacity: 0
                    visible: !isMobile()
                    Layout.maximumWidth: width
                    hoverEnabled: true

                    Behavior on width { PropertyAnimation { easing.type: Easing.InOutQuad } }
                    Behavior on opacity { PropertyAnimation { easing.type: Easing.InOutQuad } }

                    Component.onCompleted: {
                        value = Settings.volumeLevel
                        renderer.setVolume(value)

                        playBtn.hoverEnabled = true
                        resetBtn.hoverEnabled = true
                        volumeBtn.hoverEnabled = true
                    }

                    Connections { target: playBtn; onHoveredChanged: volumeSlider.update(); onPressedChanged: volumeSlider.update() }
                    Connections { target: resetBtn; onHoveredChanged: volumeSlider.update(); onPressedChanged: volumeSlider.update() }
                    Connections { target: volumeBtn; onHoveredChanged: volumeSlider.update(); onPressedChanged: volumeSlider.update() }

                    // Volume slider behavior similar to youtube
                    function update() {
                        if (opacity > 0 && (playBtn.hovered || resetBtn.hovered)) {
                            opacity = 1
                            width = 90
                        } else if (hovered || pressed || volumeBtn.hovered || volumeBtn.pressed) {
                            opacity = 1
                            width = 90
                        } else {
                            opacity = 0
                            width = 0
                        }
                    }

                    onHoveredChanged: update()
                    onPressedChanged: update()

                    onValueChanged: {
                        renderer.setVolume(value)
                        Settings.volumeLevel = value;
                    }
                }

                //spacer
                Label {
                    id: videoPositionLabel
                    Layout.minimumWidth: 0
                    Layout.fillWidth: true
                    font.bold: true
                    font.pointSize: 8
                    Material.foreground: Material.Grey
                    horizontalAlignment: Qt.AlignLeft
                    clip: true
                    function updateText() {
                        if (!isVod) return ""
                        text = Util.formatTime(seekBar.value) + "/" + Util.formatTime(duration)
                    }
                    Connections {
                        target: seekBar
                        onValueChanged: videoPositionLabel.updateText()
                    }
                    Connections {
                        target: renderer
                        onPlayingStopped: videoPositionLabel.text = ""
                    }
                }


                ComboBox {
                    id: hwaccelBox
                    font.pointSize: 9
                    font.bold: true
                    focusPolicy: Qt.NoFocus
                    flat: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: 140
                    Layout.minimumWidth: 100
                    visible: renderer.getDecoder().length > 1

                    onCurrentIndexChanged: {
                        renderer.setDecoder(currentIndex)
                        loadAndPlay()
                        Settings.decoder = hwaccelBox.model[currentIndex]
                        pArea.refreshHeaders()
                    }

                    Component.onCompleted: {
                        var decoder = renderer.getDecoder()
                        hwaccelBox.model = decoder
                        selectItem(Settings.decoder)
                        renderer.setDecoder(currentIndex)
                    }

                    function selectItem(name) {
                        for (var i in hwaccelBox.model) {
                            if (hwaccelBox.model[i] === name) {
                                currentIndex = i;
                                return;
                            }
                        }
                        //None found, attempt to select first item
                        currentIndex = 0
                    }
                }

                ComboBox {
                    id: sourcesBox
                    font.pointSize: 9
                    font.bold: true
                    focusPolicy: Qt.NoFocus
                    flat: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: 140
                    Layout.minimumWidth: 100

                    onCurrentIndexChanged: {
                        Settings.quality = sourcesBox.model[currentIndex]
                        loadAndPlay()
                        pArea.refreshHeaders()
                    }

                    function selectItem(name) {
                        for (var i in sourcesBox.model) {
                            if (sourcesBox.model[i] === name) {
                                currentIndex = i;
                                return;
                            }
                        }
                        //None found, attempt to select first item
                        currentIndex = 0
                    }
                }

                IconButtonFlat {
                    id: cropBtn
                    visible: !appFullScreen && !isMobile() && !chat.visible && parent.width > 440
                    text: "\ue3bc"
                    onClicked: fitToAspectRatio()
                }

                IconButtonFlat {
                    id: fsBtn
                    visible: !isMobile()
                    text: !appFullScreen ? "\ue5d0" : "\ue5d1"
                    onClicked: appFullScreen = !appFullScreen
                }
            }
        }
    }
}
