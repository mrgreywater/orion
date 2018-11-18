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

import QtQuick.Controls 2.1
import QtQuick 2.5
import app.orion 1.0

CommonGrid {
    id: root
    property bool showFavIcons : true
    property int clickedIndex: -1

    onCurrentItemChanged: {
        if (!currentItem || !infoDrawer.item) return
        if (infoDrawer.item._id !== currentItem._id) infoDrawer.close()
    }

    onItemClicked: {
        if (infoDrawer.item && infoDrawer.opened && clickedItem._id === infoDrawer.item._id) {
            infoDrawer.close()
            currentIndex = -1;
        } else {
            infoDrawer.show(clickedItem)
        }
    }

    onItemDoubleClicked: {
        if (clickedItem.online) {
            vodsView.search(clickedItem)
            playerView.getStreams(clickedItem)
        } else {
            playerView.getStreams(clickedItem)
            vodsView.search(clickedItem)
        }
    }

    onItemRightClicked: {
        menu.x = mX
        menu.y = mY
        menu.channel = clickedItem
        menu.open()
    }

    onItemTooltipHover: {
        if (item.online) {
            g_tooltip.displayChannel(item, getPosition)
        }
    }

    onContentYChanged: {
        if (infoDrawer.opened && !atYEnd && !atYBeginning) infoDrawer.close()
    }

    delegate: Channel {
        _id: model.id
        name: model.serviceName
        title: model.name
        logo: model.logo
        info: model.info
        viewers: model.viewers
        preview: model.preview
        online: model.online
        game: model.game
        favourite: model.favourite
        showFavIcon: showFavIcons
        width: root.cellWidth
    }

    InfoDrawer {
        id: infoDrawer
        width: parent.width
    }

    Menu {
        id: menu
        dim: false

        property var channel: undefined
        onAboutToShow: {
            g_contextMenuVisible = true
        }
        onAboutToHide: {
            g_contextMenuVisible = false
        }

        MenuItem {
            text: "Watch"
            onTriggered: {
                if (menu.channel !== undefined) {
                    vodsView.search(menu.channel)
                    playerView.getStreams(menu.channel)
                }
                menu.channel = undefined
            }
        }
        MenuItem {
            text: menu.channel !== undefined && !menu.channel.favourite ? "Follow" : "Unfollow"
            onTriggered: {
                if (menu.channel !== undefined) {
                    if (menu.channel.favourite === false)
                        app.addToFavourites(menu.channel, function() {
                            menu.channel = menu.channel
                        })
                    else
                        app.removeFromFavourites(menu.channel, function() {
                            menu.channel = menu.channel
                        })
                }
                menu.channel = undefined
            }
        }
        MenuItem {
            text: "Videos"
            onTriggered: {
                if (menu.channel !== undefined)
                    vodsView.search(menu.channel)
                menu.channel = undefined
            }
        }
    }
}

