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
import "components"
import app.orion 1.0

Page {
    id: root
    property int gamesCount: 0
    property bool checked: false

    header: SearchBar {
        id: searchBar
        input.placeholderText: "Search for games"
        onSubmit: search(true)
    }

    function search(clear) {
        console.log("Searching games: " + searchBar.text)
        if (clear) {
            gamesCount = 0
        }
        ChannelManager.searchGames(searchBar.text, gamesCount, 100);
        gamesCount += 100
    }

    function searchChannels(item) {
        searchView.search("/game " + item.title)
        requestSelectionChange(0)
    }

    Connections {
        target: ChannelManager

        onGamesSearchStarted: {
            busyIndicator.running = true
        }

        onGamesUpdated: {
            games.checkScroll()
            busyIndicator.running = false
        }
    }

    Component.onCompleted: search()

    property bool itemInView: isItemInView(this)
    onItemInViewChanged: {
        if (itemInView && !checked) {
            if (searchBar.text.length <= 0)
                search()
            checked = true
            timer.start()
        }

//        if (visible) {
//            games.positionViewAtBeginning()
//        }
    }

    CommonGrid {
        id: games
        anchors.fill: parent

        model: g_games
        delegate: Channel {
            title: model.name
            logo: model.logo
            preview: model.preview
            viewers: model.viewers
            online: true
            width: games.cellWidth
        }

        function checkScroll(){
            if (atYEnd && model.count() === gamesCount && gamesCount > 0){
                search()
            }
        }

        onUpdateTriggered: {
            search(true)
        }

        onItemClicked: {
            root.searchChannels(clickedItem)
        }

        onItemDoubleClicked: {
            root.searchChannels(clickedItem)
        }

        onItemTooltipHover: {
            if (g_tooltip)
                g_tooltip.displayGame(item, getPosition)
        }

        onAtYEndChanged: checkScroll()

        onItemRightClicked: {
            menu.item = clickedItem
            menu.x = mX
            menu.y = mY
            menu.open()
        }

        Timer {
            id: timer
            interval: 30000
            running: false
            repeat: false
            onTriggered: {
                root.checked = false
            }
        }

        BusyIndicator {
            id: busyIndicator
            visible: running
            hoverEnabled: false
            running: false
            anchors.centerIn: parent
        }
    }

    Menu {
        id: menu
        property var item

        MenuItem {
            text: "Live channels"
            onTriggered: {
                if (menu.item)
                    root.searchChannels(menu.item)
            }
        }
    }
}
