import re

from django import template
from django.utils.html import strip_tags


register = template.Library()


@register.filter
def plain_text(value):
    text = strip_tags(value or "")
    return re.sub(r"\s+", " ", text).strip()


@register.filter
def reading_time(value):
    words = plain_text(value).split()
    minutes = max(1, round(len(words) / 200))
    return f"{minutes} min"
