import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
    id: root

    property var shell: null
    property var manifest: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateBase: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string stateDirectory: stateBase + "/marcelo.podcast"
    readonly property string statePath: stateDirectory + "/library.json"
    readonly property string pluginDir: {
        var url = Qt.resolvedUrl(".").toString();
        return url.indexOf("file://") === 0 ? url.substring(7) : url;
    }
    readonly property string feedHelper: pluginDir + "bin/podcast-feed"
    readonly property string playerHelper: pluginDir + "bin/podcast-player"

    property var feeds: []
    property var episodes: []
    property var progress: ({})
    property string currentEpisodeKey: ""
    property string selectedFeedUrl: ""
    property real playbackSpeed: 1.0
    property string statusText: ""
    property string errorText: ""
    property bool stateLoaded: false
    property bool directoriesReady: false
    property bool initialRefreshDone: false

    property var fetchQueue: []
    property string activeFetchUrl: ""
    property bool fetchHandled: false

    property var playerQueue: []
    property string activePlayerAction: ""
    property bool playerHandled: false

    property var playback: ({
            connected: false,
            playing: false,
            position: 0,
            duration: 0,
            speed: 1.0,
            idle: false,
            title: "",
            path: "",
            error: ""
        })

    readonly property var currentEpisode: findEpisode(root.currentEpisodeKey)
    readonly property var currentProgress: Model.progressFor(root.progress, root.currentEpisodeKey)
    readonly property bool hasFeeds: root.feeds.length > 0
    readonly property bool hasEpisodes: root.episodes.length > 0
    readonly property bool hasPlayback: root.currentEpisode !== null

    function findEpisode(key) {
        if (!key)
            return null;
        for (var i = 0; i < root.episodes.length; i++) {
            if (root.episodes[i].key === key)
                return root.episodes[i];
        }
        return null;
    }

    function findFeed(url) {
        for (var i = 0; i < root.feeds.length; i++) {
            if (root.feeds[i].url === url)
                return root.feeds[i];
        }
        return null;
    }

    function rebuildEpisodes() {
        root.episodes = Model.flattenFeeds(root.feeds);
        if (root.currentEpisodeKey && !root.findEpisode(root.currentEpisodeKey)) {
            root.currentEpisodeKey = "";
        }
    }

    function loadState(raw) {
        if (root.stateLoaded)
            return;
        var parsed = Model.parseState(raw);
        root.feeds = parsed.feeds;
        root.progress = parsed.progress;
        root.currentEpisodeKey = parsed.currentEpisodeKey;
        root.selectedFeedUrl = parsed.selectedFeedUrl;
        root.playbackSpeed = parsed.playbackSpeed;
        root.stateLoaded = true;
        root.rebuildEpisodes();
        root.maybeInitialRefresh();
    }

    function maybeInitialRefresh() {
        if (!root.directoriesReady || !root.stateLoaded || root.initialRefreshDone)
            return;
        root.initialRefreshDone = true;
        root.refreshAll();
        root.scheduleSave();
    }

    function scheduleSave() {
        if (!root.stateLoaded || !root.directoriesReady)
            return;
        if (!stateSaveTimer.running)
            stateSaveTimer.start();
    }

    function saveState() {
        if (!root.stateLoaded || !root.directoriesReady)
            return;
        stateFile.setText(JSON.stringify(Model.stateFor(root.feeds, root.progress, root.currentEpisodeKey, root.selectedFeedUrl, root.playbackSpeed), null, 2) + "\n");
    }

    function setProgress(key, position, completed) {
        if (!key)
            return;
        var next = {};
        for (var existingKey in root.progress)
            next[existingKey] = root.progress[existingKey];
        next[key] = {
            position: Math.max(0, Number(position) || 0),
            completed: completed === true
        };
        root.progress = next;
        root.scheduleSave();
    }

    function addFeed(value) {
        var url = String(value || "").trim();
        if (!Model.validHttpUrl(url)) {
            root.errorText = "Enter an http or https feed URL.";
            return false;
        }
        if (root.findFeed(url)) {
            root.errorText = "That feed is already subscribed.";
            root.selectedFeedUrl = url;
            return false;
        }

        var next = root.feeds.slice();
        next.push({
            url: url,
            title: url,
            description: "",
            artUrl: "",
            lastUpdated: 0,
            error: "",
            episodes: []
        });
        root.feeds = next;
        root.selectedFeedUrl = url;
        root.errorText = "";
        root.statusText = "Fetching feed...";
        root.rebuildEpisodes();
        root.scheduleSave();
        root.enqueueFetch(url);
        return true;
    }

    function removeFeed(url) {
        var next = [];
        for (var i = 0; i < root.feeds.length; i++) {
            if (root.feeds[i].url !== url)
                next.push(root.feeds[i]);
        }
        if (next.length === root.feeds.length)
            return false;

        if (root.currentEpisodeKey.indexOf(String(url) + "\u001f") === 0) {
            root.stop();
            root.currentEpisodeKey = "";
        }
        root.feeds = next;
        if (root.selectedFeedUrl === url)
            root.selectedFeedUrl = "";
        root.rebuildEpisodes();
        root.statusText = "Feed removed.";
        root.errorText = "";
        root.scheduleSave();
        return true;
    }

    function refreshAll() {
        if (root.feeds.length === 0) {
            root.statusText = "Add a podcast feed to begin.";
            return;
        }
        var next = [];
        for (var i = 0; i < root.feeds.length; i++)
            next.push(root.feeds[i].url);
        root.fetchQueue = next;
        root.errorText = "";
        root.statusText = "Refreshing feeds...";
        root.pumpFetch();
    }

    function refreshFeed(url) {
        if (!root.findFeed(url))
            return;
        root.errorText = "";
        root.statusText = "Refreshing feed...";
        root.enqueueFetch(url);
    }

    function enqueueFetch(url) {
        if (!url || root.fetchQueue.indexOf(url) !== -1 || root.activeFetchUrl === url)
            return;
        var next = root.fetchQueue.slice();
        next.push(url);
        root.fetchQueue = next;
        root.pumpFetch();
    }

    function pumpFetch() {
        if (feedProc.running || root.fetchQueue.length === 0)
            return;
        root.activeFetchUrl = root.fetchQueue[0];
        root.fetchQueue = root.fetchQueue.slice(1);
        root.fetchHandled = false;
        feedProc.command = [root.feedHelper, root.activeFetchUrl];
        feedProc.running = true;
    }

    function updateFeed(url, parsedFeed) {
        var incoming = Model.normalizeFeed({
            url: url,
            title: parsedFeed.title,
            description: parsedFeed.description,
            artUrl: parsedFeed.artUrl,
            lastUpdated: Math.floor(Date.now() / 1000),
            error: "",
            episodes: parsedFeed.episodes
        });
        var next = [];
        for (var i = 0; i < root.feeds.length; i++) {
            var existing = root.feeds[i];
            if (existing.url !== url) {
                next.push(existing);
                continue;
            }
            incoming.episodes = Model.mergeEpisodes(existing.episodes, incoming.episodes);
            next.push(incoming);
        }
        root.feeds = next;
        root.rebuildEpisodes();
        root.scheduleSave();
    }

    function updateFeedError(url, message) {
        var next = [];
        for (var i = 0; i < root.feeds.length; i++) {
            var feed = root.feeds[i];
            if (feed.url !== url) {
                next.push(feed);
                continue;
            }
            var failed = {};
            for (var key in feed)
                failed[key] = feed[key];
            failed.error = message;
            next.push(failed);
        }
        root.feeds = next;
        root.errorText = message;
        root.rebuildEpisodes();
        root.scheduleSave();
    }

    function handleFeedOutput(raw) {
        root.fetchHandled = true;
        var parsed = null;
        try {
            parsed = JSON.parse(String(raw || "").trim());
        } catch (error) {
            parsed = null;
        }

        if (!parsed || parsed.ok !== true || !parsed.feed) {
            var message = parsed && parsed.error ? String(parsed.error) : "Unable to read feed.";
            root.updateFeedError(root.activeFetchUrl, message);
            return;
        }
        root.updateFeed(root.activeFetchUrl, parsed.feed);
        root.errorText = "";
        root.statusText = "Feeds updated.";
    }

    function queuePlayer(args) {
        var next = root.playerQueue.slice();
        next.push(args);
        root.playerQueue = next;
        root.pumpPlayer();
    }

    function pumpPlayer() {
        if (playerProc.running || root.playerQueue.length === 0)
            return;
        var next = root.playerQueue[0];
        root.playerQueue = root.playerQueue.slice(1);
        root.activePlayerAction = next[0] || "";
        root.playerHandled = false;
        playerProc.command = [root.playerHelper].concat(next);
        playerProc.running = true;
    }

    function playEpisode(value) {
        var episode = typeof value === "string" ? root.findEpisode(value) : value;
        if (!episode || !episode.audioUrl)
            return false;

        root.currentEpisodeKey = episode.key;
        root.selectedFeedUrl = episode.feedUrl;
        root.errorText = "";
        root.statusText = "Loading episode...";
        root.scheduleSave();

        var saved = Model.progressFor(root.progress, episode.key);
        var position = saved.completed ? 0 : saved.position;
        root.queuePlayer(["play", episode.audioUrl, episode.title, String(Math.max(0, position)),]);
        if (root.playbackSpeed !== 1.0)
            root.queuePlayer(["speed", String(root.playbackSpeed)]);
        return true;
    }

    function togglePlayPause() {
        if (!root.currentEpisode) {
            if (root.episodes.length > 0)
                return root.playEpisode(root.episodes[0]);
            root.statusText = "Add a feed with playable episodes first.";
            return false;
        }
        if (root.playback.connected) {
            root.queuePlayer(["pause"]);
            return true;
        }
        return root.playEpisode(root.currentEpisode);
    }

    function seek(seconds) {
        if (!root.playback.connected)
            return false;
        root.queuePlayer(["seek", String(Number(seconds) || 0)]);
        return true;
    }

    function setSpeed(value) {
        var clamped = Model.clampSpeed(value);
        root.playbackSpeed = clamped;
        root.scheduleSave();
        if (root.playback.connected)
            root.queuePlayer(["speed", String(clamped)]);
        return true;
    }

    function adjustSpeed(delta) {
        return root.setSpeed(root.playbackSpeed + (Number(delta) || 0));
    }

    function playNext() {
        if (root.episodes.length === 0)
            return false;
        var index = -1;
        for (var i = 0; i < root.episodes.length; i++) {
            if (root.episodes[i].key === root.currentEpisodeKey) {
                index = i;
                break;
            }
        }
        return root.playEpisode(root.episodes[(index + 1 + root.episodes.length) % root.episodes.length]);
    }

    function playPrevious() {
        if (root.episodes.length === 0)
            return false;
        var index = 0;
        for (var i = 0; i < root.episodes.length; i++) {
            if (root.episodes[i].key === root.currentEpisodeKey) {
                index = i;
                break;
            }
        }
        return root.playEpisode(root.episodes[(index - 1 + root.episodes.length) % root.episodes.length]);
    }

    function stop() {
        root.queuePlayer(["stop"]);
        root.playback = {
            connected: false,
            playing: false,
            position: 0,
            duration: 0,
            idle: false,
            title: "",
            path: "",
            error: ""
        };
    }

    function handlePlayerOutput(raw) {
        root.playerHandled = true;
        var parsed = null;
        try {
            parsed = JSON.parse(String(raw || "").trim());
        } catch (error) {
            parsed = null;
        }

        if (!parsed) {
            root.errorText = "The player returned invalid state.";
            return;
        }
        if (parsed.ok === false) {
            root.errorText = String(parsed.error || "Unable to control mpv.");
            root.playback = {
                connected: false,
                playing: false,
                position: 0,
                duration: 0,
                idle: false,
                title: "",
                path: "",
                error: root.errorText
            };
            return;
        }

        if (root.activePlayerAction !== "state")
            return;
        var wasConnected = root.playback.connected;
        root.playback = {
            connected: parsed.connected === true,
            playing: parsed.playing === true,
            position: Math.max(0, Number(parsed.position) || 0),
            duration: Math.max(0, Number(parsed.duration) || 0),
            speed: parsed.speed !== undefined ? Math.max(0.5, Math.min(3.0, Number(parsed.speed) || 1.0)) : 1.0,
            idle: parsed.idle === true,
            title: String(parsed.title || ""),
            path: String(parsed.path || ""),
            error: ""
        };

        if (!wasConnected && root.playback.connected && root.playbackSpeed !== 1.0)
            root.queuePlayer(["speed", String(root.playbackSpeed)]);

        if (root.currentEpisode && root.playback.connected) {
            var position = root.playback.position;
            var duration = root.playback.duration || root.currentEpisode.duration;
            var completed = duration > 0 && position >= duration * 0.9;
            root.setProgress(root.currentEpisode.key, position, completed);
        }
    }

    function pollPlayer() {
        if (playerProc.running || root.playerQueue.length > 0)
            return;
        root.queuePlayer(["state"]);
    }

    FileView {
        id: stateFile

        path: root.statePath
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadState(text())
        onLoadFailed: root.loadState("")
    }

    Process {
        id: ensureDirsProc

        command: ["mkdir", "-p", root.stateDirectory]
        onExited: {
            root.directoriesReady = true;
            stateFile.reload();
            root.maybeInitialRefresh();
        }
    }

    Process {
        id: feedProc

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleFeedOutput(text)
        }
        onExited: {
            if (!root.fetchHandled)
                root.updateFeedError(root.activeFetchUrl, "Feed helper exited unexpectedly.");
            root.activeFetchUrl = "";
            root.pumpFetch();
        }
    }

    Process {
        id: playerProc

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handlePlayerOutput(text)
        }
        onExited: {
            if (!root.playerHandled && root.activePlayerAction !== "state")
                root.errorText = "Player helper exited unexpectedly.";
            root.activePlayerAction = "";
            root.pumpPlayer();
        }
    }

    Timer {
        id: stateSaveTimer

        interval: 2000
        repeat: false
        onTriggered: root.saveState()
    }

    Timer {
        interval: 750
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollPlayer()
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refreshAll()
    }

    Component.onCompleted: ensureDirsProc.running = true
}
