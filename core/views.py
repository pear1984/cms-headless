from django.http import Http404
from django.shortcuts import render

from .wordpress import WordPressAPIError, WordPressClient


DEFAULT_FOOTER_CONTENT = (
    "&copy; 2025 Prometric. Todos los derechos reservados. &middot; "
    "CUIT 20931172612 &middot; "
    "Calle Monse&ntilde;or D&rsquo; Andrea 1891, Panamericana Km 55.5. CP 1629. "
    "Pilar, Provincia de Buenos Aires, Argentina &middot; "
    "Tel.: +54 9 11 3816 7749. hola@prometric.com.ar &middot; "
    '<a href="/pagina/privacy/">Pol&iacute;tica de privacidad</a> &middot; '
    '<a href="/pagina/legal/">Aviso legal</a> &middot; '
    '<a href="/pagina/cookies/">Pol&iacute;tica de cookies</a> &middot; '
    '<a href="/pagina/terms/">T&eacute;rminos y condiciones</a>'
)


def home(request):
    client = WordPressClient()
    context = base_context(client)
    return render(request, "home.html", context)


def get_menu_posts(client):
    if not client.configured:
        return []

    try:
        return client.get_posts(per_page=5, categories=3, orderby="title", order="desc")
    except WordPressAPIError:
        return []


def get_footer_content(client):
    if not client.configured:
        return DEFAULT_FOOTER_CONTENT

    try:
        page = client.get_page_by_slug("footer")
    except WordPressAPIError:
        return DEFAULT_FOOTER_CONTENT

    if not page or not page.get("content", "").strip():
        return DEFAULT_FOOTER_CONTENT

    return page["content"]


def post_detail(request, slug):
    client = WordPressClient()
    context = base_context(client)

    try:
        post = client.get_post_by_slug(slug)
    except WordPressAPIError as exc:
        return render(request, "error.html", {"error": str(exc), **context}, status=502)

    if not post:
        raise Http404("Post no encontrado")

    context["post"] = post
    return render(request, "post_detail.html", context)


def page_detail(request, slug):
    client = WordPressClient()
    context = base_context(client)

    try:
        page = client.get_page_by_slug(slug)
    except WordPressAPIError as exc:
        return render(request, "error.html", {"error": str(exc), **context}, status=502)

    if not page:
        raise Http404("Pagina no encontrada")

    context["page"] = page
    return render(request, "page_detail.html", context)


def search(request):
    client = WordPressClient()
    query = request.GET.get("q", "").strip()
    context = base_context(client)
    context["query"] = query
    context["posts"] = []

    if not query:
        return render(request, "search.html", context)

    try:
        context["posts"] = client.get_posts(search=query)
    except WordPressAPIError as exc:
        context["error"] = str(exc)

    return render(request, "search.html", context)


def base_context(client):
    context = {
        "footer_content": get_footer_content(client),
        "menu_posts": get_menu_posts(client),
        "wordpress_configured": client.configured,
        "nav_pages": [],
    }
    if not client.configured:
        return context

    try:
        context["nav_pages"] = [
            page for page in client.get_pages(per_page=10) if page.get("slug") != "footer"
        ][:6]
    except WordPressAPIError:
        context["nav_pages"] = []

    return context
