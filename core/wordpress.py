from dataclasses import dataclass
from hashlib import sha256
from html import unescape
import json
from urllib.parse import urljoin

import requests
from django.conf import settings
from django.core.cache import cache
from django.utils.html import strip_tags


class WordPressAPIError(Exception):
    """Raised when WordPress cannot be reached or returns an invalid response."""


@dataclass(frozen=True)
class WordPressClient:
    base_url: str = settings.WORDPRESS_BASE_URL
    timeout: float = settings.WORDPRESS_API_TIMEOUT
    cache_seconds: int = settings.WORDPRESS_CACHE_SECONDS

    @property
    def configured(self):
        return bool(self.base_url)

    @property
    def api_base(self):
        return urljoin(f"{self.base_url}/", "wp-json/wp/v2/")

    def get_posts(
        self,
        per_page=None,
        page=1,
        search=None,
        categories=None,
        orderby=None,
        order=None,
    ):
        params = {
            "_embed": "wp:featuredmedia,wp:term",
            "per_page": per_page or settings.WORDPRESS_POSTS_PER_PAGE,
            "page": page,
        }
        if search:
            params["search"] = search
        if categories:
            params["categories"] = categories
        if orderby:
            params["orderby"] = orderby
        if order:
            params["order"] = order

        return [self._normalize_post(item) for item in self._get("posts", params)]

    def get_post_by_slug(self, slug):
        posts = self._get(
            "posts",
            {
                "_embed": "wp:featuredmedia,wp:term",
                "slug": slug,
                "per_page": 1,
            },
        )
        return self._normalize_post(posts[0]) if posts else None

    def get_pages(self, per_page=20):
        params = {
            "per_page": per_page,
            "orderby": "menu_order",
            "order": "asc",
            "parent": 0,
        }
        return [self._normalize_page(item) for item in self._get("pages", params)]

    def get_page_by_slug(self, slug):
        pages = self._get("pages", {"slug": slug, "per_page": 1})
        return self._normalize_page(pages[0]) if pages else None

    def get_category_id_by_slug(self, slug):
        categories = self._get("categories", {"slug": slug, "per_page": 1})
        if not categories:
            return None
        return categories[0].get("id")

    def _get(self, path, params=None):
        if not self.configured:
            return []

        params = params or {}
        cache_key = None
        if self.cache_seconds > 0:
            cache_key = self._cache_key(path, params)
            cached = cache.get(cache_key)
            if cached is not None:
                return cached

        url = urljoin(self.api_base, path)
        try:
            response = requests.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()
        except requests.RequestException as exc:
            raise WordPressAPIError(f"No se pudo conectar con WordPress: {exc}") from exc

        try:
            data = response.json()
        except ValueError as exc:
            raise WordPressAPIError("WordPress respondio con un JSON invalido.") from exc

        if cache_key:
            cache.set(cache_key, data, self.cache_seconds)
        return data

    def _cache_key(self, path, params):
        payload = json.dumps({"path": path, "params": params}, sort_keys=True)
        digest = sha256(payload.encode("utf-8")).hexdigest()
        return f"wp-headless:{digest}"

    def _normalize_post(self, item):
        return {
            "id": item.get("id"),
            "slug": item.get("slug", ""),
            "date": item.get("date"),
            "title": self._rendered(item, "title", "Sin titulo"),
            "excerpt": self._rendered(item, "excerpt", ""),
            "summary": self._summary(item),
            "content": self._rendered(item, "content", ""),
            "link": item.get("link"),
            "featured_image": self._featured_image(item),
            "categories": self._terms(item, "category"),
            "tags": self._terms(item, "post_tag"),
        }

    def _normalize_page(self, item):
        return {
            "id": item.get("id"),
            "slug": item.get("slug", ""),
            "title": self._rendered(item, "title", "Sin titulo"),
            "content": self._rendered(item, "content", ""),
            "excerpt": self._rendered(item, "excerpt", ""),
        }

    def _rendered(self, item, key, fallback=""):
        value = item.get(key, {})
        rendered = value.get("rendered") if isinstance(value, dict) else value
        return unescape(rendered or fallback)

    def _summary(self, item):
        excerpt = strip_tags(self._rendered(item, "excerpt", ""))
        if excerpt:
            return unescape(excerpt).strip()
        content = strip_tags(self._rendered(item, "content", ""))
        return unescape(content[:180]).strip()

    def _featured_image(self, item):
        embedded = item.get("_embedded", {})
        media = embedded.get("wp:featuredmedia") or []
        if not media:
            return None

        source = media[0].get("source_url")
        alt = media[0].get("alt_text") or self._rendered(item, "title", "")
        return {"url": source, "alt": alt} if source else None

    def _terms(self, item, taxonomy):
        embedded = item.get("_embedded", {})
        groups = embedded.get("wp:term") or []
        terms = []
        for group in groups:
            for term in group:
                if term.get("taxonomy") == taxonomy:
                    terms.append({"id": term.get("id"), "name": term.get("name")})
        return terms
