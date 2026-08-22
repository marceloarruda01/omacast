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
