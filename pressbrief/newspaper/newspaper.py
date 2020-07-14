import logging
import time
from itertools import chain, islice
from typing import List

import feedparser

from newspaper.news import News


class Newspaper:
    def __init__(self, name: str, rss_feeds: List[str], limit: int) -> None:
        self.logger = logging.getLogger(__name__)
        self.name = name
        self.rss_feeds = rss_feeds
        self.limit = limit

    def extract_news_list(self) -> List[News]:
        self.logger.info(f"Downloading news for {self.name} ...")

        news_list = chain.from_iterable(
            map(
                lambda rss_feed: [
                    self._extract_news(rss_entry)
                    for rss_entry in islice(self._get_today_rss_entries(rss_feed), 0, self.limit)
                ],
                self.rss_feeds,
            )
        )

        self.logger.info("News downloaded")
        return news_list

    def _get_today_rss_entries(self, rss_feed: str) -> List[feedparser.FeedParserDict]:
        rss_entries = feedparser.parse(rss_feed).entries
        return filter(self._is_today_news, rss_entries)

    def _extract_news(self, rss_entry: feedparser.FeedParserDict) -> News:
        try:
            title = rss_entry.title
            summary = (
                rss_entry.summary if hasattr(rss_entry, "summary") else
                rss_entry.description if hasattr(rss_entry, "description") else
                rss_entry.subtitle
            )
            url = rss_entry.link
            published_date = (
                rss_entry.published_parsed if hasattr(rss_entry, "published_parsed") else 
                rss_entry.updated_parsed if hasattr(rss_entry, "updated_parsed") else
                rss_entry.date_parsed
            )
            author = rss_entry.author if hasattr(rss_entry, "author") else None
        except AttributeError as e:
            self.logger.warning(f"Invalid data schema ({e.args}), skipping ...")

        return News(title, summary, url, published_date, author)

    def _is_today_news(self, rss_entry: feedparser.FeedParserDict) -> bool:
        published_time = (
            rss_entry.published_parsed if hasattr(rss_entry, "published_parsed") else
            rss_entry.updated_parsed if hasattr(rss_entry, "updated_parsed") else 
            rss_entry.date_parsed if hasattr(rss_entry, "date_parsed") else
            None
        )
        time_diff = (time.mktime(time.gmtime()) - time.mktime(published_time)) / 3600

        return published_time is not None and time_diff < 24
