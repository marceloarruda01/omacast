const assert = require("node:assert/strict");
const test = require("node:test");
const Model = require("../Model.js");

test("normalizes feeds and creates stable episode keys", () => {
    const feed = Model.normalizeFeed({
        url: "https://example.test/feed.xml",
        title: "Example",
        episodes: [{ id: "one", title: "One", audioUrl: "https://example.test/one.mp3" }],
    });

    assert.equal(feed.episodes[0].key, "https://example.test/feed.xml\u001fone");
    assert.equal(Model.validHttpUrl(feed.url), true);
    assert.equal(Model.validHttpUrl("file:///tmp/feed.xml"), false);
});

test("new feed data replaces matching episodes and keeps older episodes", () => {
    const existing = [{ key: "old", publishedAt: 1, title: "Old" }];
    const incoming = [{ key: "new", publishedAt: 3, title: "New" }];
    const merged = Model.mergeEpisodes(existing, incoming, 100);

    assert.deepEqual(merged.map((episode) => episode.key), ["new", "old"]);
});

test("filters episodes and formats progress", () => {
    const episodes = [
        { key: "one", title: "Linux News", feedTitle: "Tech", summary: "Kernel", duration: 600 },
        { key: "two", title: "Garden", feedTitle: "Home", summary: "Plants", duration: 3600 },
    ];
    const progress = { one: { position: 150, completed: false } };

    assert.equal(Model.filterEpisodes(episodes, "kernel", "").length, 1);
    assert.equal(Model.progressRatio(episodes[0], progress), 0.25);
    assert.equal(Model.formatDuration(3661), "1:01:01");
    assert.equal(Model.formatPosition(150, 600), "2:30 / 10:00");
});

test("clampSpeed snaps to 0.25x steps", () => {
    assert.equal(Model.clampSpeed(1.0), 1.0);
    assert.equal(Model.clampSpeed(0.1), 0.5);
    assert.equal(Model.clampSpeed(5.0), 3.0);
    assert.equal(Model.clampSpeed(0.75), 0.75);
    assert.equal(Model.clampSpeed(1.1), 1.0);
    assert.equal(Model.clampSpeed(1.3), 1.25);
    assert.equal(Model.clampSpeed(1.6), 1.5);
    assert.equal(Model.clampSpeed(1.12), 1.0);
    assert.equal(Model.clampSpeed(1.13), 1.25);
    assert.equal(Model.clampSpeed(undefined), 1.0);
});

test("formatSpeed formats speed values", () => {
    assert.equal(Model.formatSpeed(1.0), "1x");
    assert.equal(Model.formatSpeed(1.1), "1x");
    assert.equal(Model.formatSpeed(1.5), "1.5x");
    assert.equal(Model.formatSpeed(0.75), "0.75x");
    assert.equal(Model.formatSpeed(2.0), "2x");
});

test("parseState loads and persists playbackSpeed", () => {
    const state = Model.parseState(JSON.stringify({ playbackSpeed: 1.5 }));
    assert.equal(state.playbackSpeed, 1.5);

    const defaultState = Model.parseState("{}");
    assert.equal(defaultState.playbackSpeed, 1.0);

    const clamped = Model.parseState(JSON.stringify({ playbackSpeed: 10 }));
    assert.equal(clamped.playbackSpeed, 3.0);
});

test("stateFor includes playbackSpeed", () => {
    const s = Model.stateFor([], {}, "", "", 2.0);
    assert.equal(s.playbackSpeed, 2.0);

    const def = Model.stateFor([], {}, "", "");
    assert.equal(def.playbackSpeed, 1.0);
});
