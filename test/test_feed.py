import importlib.machinery
import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "bin" / "podcast-feed"
LOADER = importlib.machinery.SourceFileLoader("podcast_feed", str(SCRIPT))
SPEC = importlib.util.spec_from_loader("podcast_feed", LOADER)
assert SPEC
podcast_feed = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(podcast_feed)


class FeedParserTest(unittest.TestCase):
    def test_rss_enclosure_and_metadata(self):
        raw = b"""
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Example Show</title>
            <description>A <b>useful</b> show.</description>
            <itunes:image href="https://example.test/art.jpg" />
            <item>
              <title>Episode One</title>
              <guid>episode-1</guid>
              <pubDate>Sat, 22 Aug 2026 12:00:00 GMT</pubDate>
              <itunes:duration>01:02:03</itunes:duration>
              <description><![CDATA[<p>Hello <b>world</b>.</p>]]></description>
              <enclosure url="https://example.test/episode.mp3" type="audio/mpeg" />
            </item>
          </channel>
        </rss>
        """

        parsed = podcast_feed.parse_feed(raw, "https://example.test/feed.xml")

        self.assertEqual(parsed["title"], "Example Show")
        self.assertEqual(parsed["artUrl"], "https://example.test/art.jpg")
        self.assertEqual(len(parsed["episodes"]), 1)
        episode = parsed["episodes"][0]
        self.assertEqual(episode["id"], "episode-1")
        self.assertEqual(episode["duration"], 3723)
        self.assertEqual(episode["summary"], "Hello world.")

    def test_atom_enclosure(self):
        raw = b"""
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>Atom Show</title>
          <entry>
            <id>tag:example.test,2026:one</id>
            <title>Atom Episode</title>
            <updated>2026-08-22T12:00:00Z</updated>
            <link rel="enclosure" href="https://example.test/atom.ogg" type="audio/ogg" />
          </entry>
        </feed>
        """

        parsed = podcast_feed.parse_feed(raw, "https://example.test/atom.xml")

        self.assertEqual(parsed["title"], "Atom Show")
        self.assertEqual(parsed["episodes"][0]["audioUrl"], "https://example.test/atom.ogg")


if __name__ == "__main__":
    unittest.main()
