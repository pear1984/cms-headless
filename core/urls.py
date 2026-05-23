from django.urls import path

from . import views


urlpatterns = [
    path("", views.home, name="home"),
    path("buscar/", views.search, name="search"),
    path("<slug:slug>/", views.content_detail, name="post_detail"),
    path("<slug:slug>/", views.content_detail, name="page_detail"),
]
