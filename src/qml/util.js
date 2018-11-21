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

.pragma library

function copyChannel(channel) {
    return {
        _id: channel._id,
        name: channel.name,
        title: channel.title,
        info: channel.info,
        logo: channel.logo,
        preview: channel.preview,
        game: channel.game,
        viewers: channel.viewers,
        online: channel.online,
        favourite: channel.favourite
    };
}

//Returns time in HH:MM:SS presentation, arg in secs
function getTime(totalSec){

    if (!totalSec)
        return "NaN"

    var days = Math.floor(parseInt(totalSec / (3600 * 24)))
    var hours = parseInt(totalSec / 3600) % 24;
    var minutes = parseInt(totalSec / 60) % 60;
    var seconds = totalSec % 60;

    var result = "";

    if (days > 0)
        result += days + ":";
    if (days > 0 || hours > 0)
        result += hours + ":";
    result += (minutes < 10 ? "0" + minutes : minutes) + ":";
    result += (seconds  < 10 ? "0" + seconds : seconds);

    return result
}

// http://crocodillon.com/blog/parsing-emoji-unicode-in-javascript
var emojiPattern;
function getEmojiPattern() {
    //probably not all emojis, but coves most of them for now
    if (emojiPattern) return emojiPattern
    var ranges = [
        '\ud83c[\udf00-\udfff]', // U+1F300 to U+1F3FF
        '\ud83d[\udc00-\ude4f]', // U+1F400 to U+1F64F
        '\ud83d[\ude80-\udeff]'  // U+1F680 to U+1F6FF
    ];
    emojiPattern = new RegExp(ranges.join('|'), 'g');
    return emojiPattern
}

/*
   Some urls to consider

   twitch.tv
   twitch.tv/giantwaffle/subscribe
   twitch.tv/giantwaffle/subscribe/
   [twitch.tv/giantwaffle/subscribe]
   (twitch.tv/giantwaffle/subscribe)
   https://www.youtube.com:443/watch?v=5eQi3We_whE
   https://i.imgur.com/jfhaAPP.jpg
*/
var urlPattern = /\b(http(s)?:\/\/)?(www\.)?([\w\-\+@:%~#=]{1,256}\.){1,3}[a-z]{2,63}(:\d{1,5}\b)?(\/([\w\-\+@:%~#=?&]+|\.+\b|\.+\/)*)*/g
function makeUrl(str) {
    var pref = "";
    if (str.length && (str.charAt(0) === " ")) {
        pref = "&nbsp;";
        str = str.substring(1);
    }

    var out = pref + str.replace(urlPattern, function(match) {
        var hasHttp = match.startsWith("https://") || match.startsWith("http://")
        // filter out some likely false positives that might occur in natural writing
        // avoid matching something like: "this.is.not.a.url" or "hey.you"
        // while still allowing some short urls like "google.com", "twitch.tv" etc.
        if (!hasHttp && !match.startsWith("www.") && match.indexOf("/") === -1 && !match.endsWith(".com") && !match.endsWith(".tv") && !match.endsWith(".org"))
            return match
        return '<a href="' + (hasHttp ? match : ("http://" + match)) + '">' + match + '</a>';
    });

    // console.log("makeUrl", str, out);
    return out;
}

function isUrl(str) {
    var result = str.length > 5 && str.indexOf(".") !== -1 && !!str.match(urlPattern);

    // console.log("isUrl", str, result);
    return result
}

function endsWith(s, suffix) {
    return s.length >= suffix.length && s.substring(s.length - suffix.length) === suffix;
}

function decodeHtml(html) {
    var entities = {
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\""
    }

    var cur = 0;
    var parts = [];
    while (true) {
        var pos = html.indexOf("&", cur);
        if (pos == -1) {
            break;
        }

        parts.push(html.substring(cur, pos));

        var end = html.indexOf(";", pos + 1);
        if (end == -1) {
            console.log("unterminated entity " + html.substring(pos));
            break;
        }

        var entityName = html.substring(pos + 1, end);
        var value = entities[entityName];

        if (!entityName) {
            console.log("unknown entity " + entityName);
            break;
        }

        parts.push(value);

        cur = end + 1;
    }
    parts.push(html.substring(cur));
    return parts.join("");
}

function encodeHtml(unsafe) {
    // per https://stackoverflow.com/questions/6234773/can-i-escape-html-special-chars-in-javascript
    return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function inverseRegex(s) {
    var out = [];
    var unconfirmed = "";
    var showDebug = false;
    for (var i = 0; i < s.length; i++) {
        var cur = s.charAt(i);
        switch (cur) {
        case "\\":
            cur = s.charAt(++i);
            out.push(unconfirmed)
            unconfirmed = cur;
            break;
        case "?":
            // previous was optional
            // assume nope
            unconfirmed = "";
            break;
        case "(":
            // recurse on this part of the regex until | or ) at this depth
            var start = i + 1;
            var end = null;
            var ch;
            var running = true;
            var depth = 0;
            while (running) {
                ch = s.charAt(++i);
                switch (ch) {
                case "\\":
                    i++;
                    break;
                case "(":
                    depth++;
                    break;
                case ")":
                    if (depth == 0) {
                        if (end == null) {
                            end = i;
                        }
                        running = false;
                    } else {
                        depth--;
                    }
                    break;
                case "|":
                    if (depth == 0) {
                        if (end == null) {
                            end = i;
                        }
                    }
                    break;
                }
            }
            out.push(unconfirmed);
            var regexPart = s.substring(start, end);
            // console.log(s, "recursing on", regexPart);
            // showDebug = true;
            unconfirmed = inverseRegex(regexPart);
            break;
        case "[":
            cur = s.charAt(++i);
            if (cur == "\\") {
                cur = s.charAt(++i);
            }

            var end = s.indexOf("]", i + 1);
            if (end == -1) {
                console.log("unterminated [");
                showDebug = true;
            }
            i = end;

            out.push(unconfirmed);
            unconfirmed = cur;
            break;
        default:
            out.push(unconfirmed);
            unconfirmed = cur;
        }
    }

    out.push(unconfirmed);
    out = out.join("");

    /*
    // test the generated text
    var testFailed;

    try {
        var r = new RegExp(s);
        var match = r.exec(out);
        testFailed = match == null || match[0] != out;
    } catch (e) {
        console.log(e, out);
        testFailed = true;
    }
    if (testFailed || showDebug) {
        // mismatch
        console.log("Converted regex " + s + " output " + out + (testFailed? " doesn't match": ""));
    }
    */

    return out;
}

function regexExactMatch(regex, text) {
    var match = regex.exec(text);
    return match && match[0] === text;
}

function getRandomColor() {
    var letters = '0123456789ABCDEF';
    var color = '#';
    var minBrightness = 85;
    var maxBrightness = 240;
    var brightnessRange = maxBrightness - minBrightness + 1;
    for (var i = 0; i < 3; i++ ) {
        var colorVal = minBrightness + Math.floor(brightnessRange * Math.random());
        color += letters[Math.floor(colorVal / 16)] + letters[colorVal % 16];
    }
    return color;
}

function keysStr(obj) {
    var parts = [];
    for (var i in obj) {
        parts.push(i);
    }
    return parts.join(", ");
}

function objectAssign() {
    var target = arguments[0];
    for (var i = 1; i < arguments.length; i++) {
        var source = arguments[i];
        for (var key in source) {
            if (source.hasOwnProperty(key)) {
                target[key] = source[key];
            }
        }
    }
    return target;
}

function formatTime(seconds) {
    seconds = Math.floor(seconds)
    var hours = Math.floor(seconds / 3600)
    var minutes = Math.floor(seconds / 60) % 60
    seconds = seconds % 60
    hours = hours < 10 ? '0' + hours : hours
    minutes = minutes < 10 ? '0' + minutes : minutes
    seconds = seconds < 10 ? '0' + seconds : seconds
    return hours + ":" + minutes + ":" + seconds
}

function requestJSON(url, callback) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = (function(xhr) {
        return function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                callback(JSON.parse(xhr.responseText));
            }
        }
    })(xhr);
    xhr.open('GET', url, true);
    xhr.send('');
}

var timerComponent = Qt.createQmlObject('import QtQuick 2.5; Component { Timer {} }', Qt.application);
var freeTimers = [];
function setTimeout(callback, timeout) {
    var timer = freeTimers.length > 0 ? freeTimers.pop() : timerComponent.createObject(Qt.application);
    timer.interval = timeout || 0;
    var onTriggered = function() {
        timer.triggered.disconnect(onTriggered);
        timer.stop();
        freeTimers.push(timer);
        callback();
    }
    timer.triggered.connect(onTriggered);
    timer.start();
}

var intervalTimerIndex = 0;
var intervalTimer = {};
function setInterval(callback, timeout) {
    var timer = freeTimers.length > 0 ? freeTimers.pop() : timerComponent.createObject(Qt.application);
    timer.interval = Math.max(10, timeout || 0);
    timer.repeat = true;
    timer.triggered.connect(callback);
    timer.start();
    intervalTimer[intervalTimerIndex] = {
        timer: timer,
        callback: callback
    }
    return intervalTimerIndex++;
}

function clearInterval(val) {
    if (!intervalTimer[val]) return;
    var timer = intervalTimer[val].timer;
    var callback = intervalTimer[val].callback;
    timer.triggered.disconnect(callback);
    timer.stop();
    timer.repeat = false;
    freeTimers.push(timer);
    delete intervalTimer[val];
}

function globalPosition(item, localX, localY) {
    if (!item) return Qt.point(0, 0);
    var pt = Qt.point(item.x, item.y);
    while (item.parent) {
        item = item.parent
        pt.x += item.x;
        pt.y += item.y;
    }
    pt.x += localX || 0
    pt.y += localY || 0
    return pt
}

function localPosition(item, globalX, globalY) {
    var pt = Qt.point(globalX || 0, globalY || 0);
    var global = globalPosition(item)
    pt.x -= global.x
    pt.y -= global.y
    return pt
}
