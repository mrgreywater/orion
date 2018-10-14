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
import QtMultimedia 5.5

/* Interface for backend Multimedia

Functions needed:
load(src, start)    -- Loads stream src, if given, start sets the starting milliseconds in vods
resume()            -- Forces resume
pause()             -- Forces pause
togglePause()       -- Toggles between playing and pausing
stop()              -- Stops playback
seekTo(pos)         -- Seeks to milliseconds in the current source, works only on vods
setVolume(vol)      -- Number between 0 - 100
getDecoder()        -- Return list of video decoders
setDecoder(idx)     -- Set video decoder

Signals needed:
playingResumed()    -- Signaled when playback toggles from paused / stopped to playing
playingPaused()     -- Signaled when playback pauses
playingStopped()    -- Signaled when playback stops (stream ends)
volumeChanged()     -- Signaled when volume changes internally

Variables needed:
status              -- string "PLAYING" | "PAUSED" | "STOPPING" | "STOPPED"
position            -- Milliseconds in playback
volume              -- volume between 0 - 100

*/

Item {
    id: root

    function load(src, start) {
        console.log("Loading src", src, start)
        status = "BUFFERING"

        stop();

        if (start >= 0) {
            seekTo(start)
        }

        renderer.source = src

        resume()
    }

    function resume() {
        renderer.play()
    }

    function pause() {
        renderer.pause()
    }

    function stop() {
        status = "STOPPING";
        renderer.stop()
    }

    function togglePause() {
        if (status == "PAUSED" || status == "STOPPING" || status == "STOPPED")
            resume()
        else
            pause()
    }

    function seekTo(pos) {
        if (status !== "STOPPING")
            status = "BUFFERING"
        renderer.seek(pos * 1000)
        root.position = pos
    }

    function setVolume(vol) {
        volume = Math.round(vol)
    }

    function getDecoder() {
        var defaultDecoders = []
        return defaultDecoders
    }

    function setDecoder(idx) {

    }

    signal playingResumed()
    signal playingPaused()
    signal playingStopped()
    signal volumeChangedInternally()

    property string status: "STOPPED"
    onStatusChanged: {
        switch (status) {
        case "PLAYING":
            playingResumed();
            break;
        case "PAUSED":
            playingPaused();
            break;
        case "STOPPED":
            playingStopped();
            break;
        }
    }

    property int position: 0
    onPositionChanged: {
        //console.log("Position", position)
    }

    property double volume: 100
    onVolumeChanged: {
        //console.log("Volume", volume)
        renderer.volume = volume / 100.0
    }

    MediaPlayer {
        id: renderer

        onError: {
            console.error(errorString)
        }

        function updateStatus() {
            if (status === MediaPlayer.Buffering) {
                root.status = "BUFFERING"
            } else if (playbackState === MediaPlayer.PlayingState) {
                root.status = "PLAYING"
            } else if (playbackState === MediaPlayer.PausedState) {
                root.status = "PAUSED"
            } else if (playbackState === MediaPlayer.StoppedState) {
                root.status = "STOPPED"
            }
        }

        onStatusChanged: updateStatus()
        onPlaybackStateChanged: updateStatus()

        onStopped: {
            root.status = "STOPPED"
            root.playingStopped()
        }

        onPaused: {
            root.status = "PAUSED"
            root.playingPaused()
        }

        onPlaying: {
            root.status = "PLAYING"
            root.playingResumed()
        }

        onPositionChanged: {
            if (root.status == "STOPPING" && position == 0) {
                // suppress this position update; during a reload we want to resume from the previous playing position
                return;
            }
            var pos = position / 1000
            if (root.position !== pos) {
                root.position = pos
                updateStatus()
            }
        }
    }

    Rectangle {
        color: "black"
        anchors.fill: parent

        VideoOutput {
            id: output
            anchors.fill: parent
            source: renderer
        }
    }
}
