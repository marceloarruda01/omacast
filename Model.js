// Pure data helpers for the podcast plugin. Keep this file independent of QML
// so feed merging and progress formatting can be tested with Node.

var MAX_EPISODES_PER_FEED = 100;
var SEPARATOR = "\u001f";
var SPEED_MIN = 0.5;
var SPEED_MAX = 3.0;
var SPEED_STEP = 0.25;
var SPEED_DEFAULT = 1.0;

function text(value, fallback) {
    var result = value === undefined || value === null ? "" : String(value).trim();
    return result || (fallback || "");
}

function number(value, fallback) {
    var result = Number(value);
    return isFinite(result) ? result : fallback;
}

function validHttpUrl(value) {
    var url = text(value);
    return /^https?:\/\/[^\s]+$/i.test(url);
}

function episodeKey(feedUrl, episodeId) {
    return text(feedUrl) + SEPARATOR + text(episodeId);
}

function normalizeEpisode(raw, feed) {
    var source = raw || {};
    var feedUrl = text(feed && feed.url);
    var id = text(source.id, source.guid || source.audioUrl);
    var audioUrl = text(source.audioUrl);
    if (!id || !audioUrl) return null;

    return {
        id: id,
        key: episodeKey(feedUrl, id),
        title: text(source.title, "Untitled episode"),
        audioUrl: audioUrl,
        pageUrl: text(source.pageUrl),
        summary: text(source.summary),
        publishedAt: number(source.publishedAt, 0),
        duration: Math.max(0, number(source.duration, 0)),
        artUrl: text(source.artUrl, text(feed && feed.artUrl)),
        explicit: !!source.explicit,
    };
}

function normalizeFeed(raw) {
    var source = raw || {};
    var url = text(source.url);
    var feed = {
        url: url,
        title: text(source.title, url || "Podcast"),
        description: text(source.description),
        artUrl: text(source.artUrl),
        lastUpdated: Math.max(0, number(source.lastUpdated, 0)),
        error: text(source.error),
        episodes: [],
    };

    var sourceEpisodes = Array.isArray(source.episodes) ? source.episodes : [];
    for (var i = 0; i < sourceEpisodes.length; i++) {
        var episode = normalizeEpisode(sourceEpisodes[i], feed);
        if (episode) feed.episodes.push(episode);
    }
    feed.episodes = mergeEpisodes([], feed.episodes, MAX_EPISODES_PER_FEED);
    return feed;
}

function parseState(raw) {
    var empty = {
        feeds: [],
        progress: {},
        currentEpisodeKey: "",
        selectedFeedUrl: "",
        playbackSpeed: SPEED_DEFAULT,
    };

    try {
        var parsed = JSON.parse(String(raw || "").trim());
        if (!parsed || typeof parsed !== "object") return empty;

        var feeds = [];
        var sourceFeeds = Array.isArray(parsed.feeds) ? parsed.feeds : [];
        for (var i = 0; i < sourceFeeds.length; i++) {
            var feed = normalizeFeed(sourceFeeds[i]);
            if (validHttpUrl(feed.url)) feeds.push(feed);
        }

        var progress = {};
        if (parsed.progress && typeof parsed.progress === "object") {
            for (var key in parsed.progress) {
                var item = parsed.progress[key];
                if (!item || typeof item !== "object") continue;
                progress[key] = {
                    position: Math.max(0, number(item.position, 0)),
                    completed: item.completed === true,
                };
            }
        }

        empty.feeds = feeds;
        empty.progress = progress;
        empty.currentEpisodeKey = text(parsed.currentEpisodeKey);
        empty.selectedFeedUrl = text(parsed.selectedFeedUrl);
        empty.playbackSpeed = clampSpeed(parsed.playbackSpeed !== undefined ? parsed.playbackSpeed : SPEED_DEFAULT);
        return empty;
    } catch (error) {
        return empty;
    }
}

function mergeEpisodes(existing, incoming, limit) {
    var result = [];
    var seen = {};
    var values = [];
    var first = Array.isArray(incoming) ? incoming : [];
    var second = Array.isArray(existing) ? existing : [];
    for (var i = 0; i < first.length; i++) values.push(first[i]);
    for (var j = 0; j < second.length; j++) values.push(second[j]);

    for (var k = 0; k < values.length; k++) {
        var episode = values[k];
        if (!episode || !episode.key || seen[episode.key]) continue;
        seen[episode.key] = true;
        result.push(episode);
    }

    result.sort(function (a, b) {
        return number(b.publishedAt, 0) - number(a.publishedAt, 0);
    });
    return result.slice(0, limit || MAX_EPISODES_PER_FEED);
}

function flattenFeeds(feeds) {
    var result = [];
    var values = Array.isArray(feeds) ? feeds : [];
    for (var i = 0; i < values.length; i++) {
        var feed = values[i];
        var episodes = feed && Array.isArray(feed.episodes) ? feed.episodes : [];
        for (var j = 0; j < episodes.length; j++) {
            var episode = episodes[j];
            result.push({
                id: episode.id,
                key: episode.key || episodeKey(feed.url, episode.id),
                title: episode.title,
                audioUrl: episode.audioUrl,
                pageUrl: episode.pageUrl,
                summary: episode.summary,
                publishedAt: number(episode.publishedAt, 0),
                duration: Math.max(0, number(episode.duration, 0)),
                artUrl: episode.artUrl || feed.artUrl || "",
                explicit: episode.explicit === true,
                feedUrl: feed.url,
                feedTitle: feed.title,
                feedArtUrl: feed.artUrl || "",
            });
        }
    }
    result.sort(function (a, b) {
        return b.publishedAt - a.publishedAt;
    });
    return result;
}

function filterEpisodes(episodes, query, feedUrl) {
    var result = [];
    var needle = text(query).toLowerCase();
    var values = Array.isArray(episodes) ? episodes : [];
    for (var i = 0; i < values.length; i++) {
        var episode = values[i];
        if (feedUrl && episode.feedUrl !== feedUrl) continue;
        if (
            needle &&
            (text(episode.title) + " " + text(episode.feedTitle) + " " + text(episode.summary))
                .toLowerCase()
                .indexOf(needle) === -1
        )
            continue;
        result.push(episode);
    }
    return result;
}

function progressFor(progress, key) {
    var value = progress && progress[key];
    if (!value || typeof value !== "object") return { position: 0, completed: false };
    return {
        position: Math.max(0, number(value.position, 0)),
        completed: value.completed === true,
    };
}

function progressRatio(episode, progress) {
    var duration = number(episode && episode.duration, 0);
    if (duration <= 0) return 0;
    var position = progressFor(progress, episode.key).position;
    return Math.max(0, Math.min(1, position / duration));
}

function formatDuration(seconds) {
    var total = Math.max(0, Math.round(number(seconds, 0)));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor((total % 3600) / 60);
    var remainder = total % 60;
    if (hours > 0)
        return hours + ":" + String(minutes).padStart(2, "0") + ":" + String(remainder).padStart(2, "0");
    return minutes + ":" + String(remainder).padStart(2, "0");
}

function formatDate(timestamp) {
    var value = number(timestamp, 0);
    if (value <= 0) return "";
    return new Date(value * 1000).toISOString().slice(0, 10);
}

function formatPosition(position, duration) {
    var current = formatDuration(position);
    var total = number(duration, 0) > 0 ? formatDuration(duration) : "--:--";
    return current + " / " + total;
}

function truncate(value, length) {
    var source = text(value);
    var max = Math.max(1, number(length, 140));
    if (source.length <= max) return source;
    return source.slice(0, max - 1).trimEnd() + "...";
}

function clampSpeed(value) {
    var n = number(value, SPEED_DEFAULT);
    if (!isFinite(n)) return SPEED_DEFAULT;
    var snapped = Math.round(n / SPEED_STEP) * SPEED_STEP;
    return Math.round(Math.max(SPEED_MIN, Math.min(SPEED_MAX, snapped)) * 100) / 100;
}

function formatSpeed(value) {
    var n = clampSpeed(value);
    return (Math.round(n * 100) / 100).toFixed(2).replace(/\.?0+$/, "") + "x";
}

function stateFor(feeds, progress, currentEpisodeKey, selectedFeedUrl, playbackSpeed) {
    return {
        version: 1,
        feeds: Array.isArray(feeds) ? feeds : [],
        progress: progress || {},
        currentEpisodeKey: text(currentEpisodeKey),
        selectedFeedUrl: text(selectedFeedUrl),
        playbackSpeed: clampSpeed(playbackSpeed !== undefined ? playbackSpeed : SPEED_DEFAULT),
    };
}

if (typeof module !== "undefined") {
    module.exports = {
        MAX_EPISODES_PER_FEED: MAX_EPISODES_PER_FEED,
        SPEED_MIN: SPEED_MIN,
        SPEED_MAX: SPEED_MAX,
        SPEED_STEP: SPEED_STEP,
        SPEED_DEFAULT: SPEED_DEFAULT,
        validHttpUrl: validHttpUrl,
        episodeKey: episodeKey,
        normalizeEpisode: normalizeEpisode,
        normalizeFeed: normalizeFeed,
        parseState: parseState,
        mergeEpisodes: mergeEpisodes,
        flattenFeeds: flattenFeeds,
        filterEpisodes: filterEpisodes,
        progressFor: progressFor,
        progressRatio: progressRatio,
        formatDuration: formatDuration,
        formatDate: formatDate,
        formatPosition: formatPosition,
        formatSpeed: formatSpeed,
        clampSpeed: clampSpeed,
        truncate: truncate,
        stateFor: stateFor,
    };
}
