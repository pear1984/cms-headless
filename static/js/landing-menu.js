// Cookie consent banner
(function () {
  const STORAGE_KEY = "cookie_consent";

  const banner = document.getElementById("cookie-banner");
  if (!banner) return;

  if (localStorage.getItem(STORAGE_KEY)) return;

  banner.hidden = false;
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      banner.classList.add("is-visible");
    });
  });

  function dismiss(choice) {
    localStorage.setItem(STORAGE_KEY, choice);
    banner.classList.add("is-hiding");
    banner.classList.remove("is-visible");
    banner.addEventListener("transitionend", () => {
      banner.hidden = true;
    }, { once: true });
  }

  banner.querySelector("[data-cookie-accept]")?.addEventListener("click", () => dismiss("accepted"));
  banner.querySelector("[data-cookie-reject]")?.addEventListener("click", () => dismiss("rejected"));
})();

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-landing-menu]").forEach((menu) => {
    const summary = menu.querySelector("summary");
    const links = menu.querySelectorAll("a");

    const syncExpanded = () => {
      summary.setAttribute("aria-expanded", menu.open ? "true" : "false");
    };

    menu.addEventListener("toggle", syncExpanded);
    menu.addEventListener("mouseleave", () => {
      if (window.matchMedia("(hover: hover)").matches) {
        menu.open = false;
        syncExpanded();
      }
    });

    links.forEach((link) => {
      link.addEventListener("click", () => {
        menu.open = false;
        syncExpanded();
      });
    });

    syncExpanded();
  });

  const drawer = document.querySelector("[data-login-drawer]");
  const backdrop = document.querySelector(".login-backdrop");
  const openButton = document.querySelector("[data-login-open]");
  const closeButtons = document.querySelectorAll("[data-login-close]");
  const LOGIN_HASH = "#login";

  if (!drawer || !backdrop || !openButton) {
    return;
  }

  const setLoginOpen = (isOpen) => {
    drawer.classList.toggle("is-open", isOpen);
    backdrop.classList.toggle("is-open", isOpen);
    drawer.setAttribute("aria-hidden", isOpen ? "false" : "true");
    openButton.setAttribute("aria-expanded", isOpen ? "true" : "false");

    if (isOpen) {
      backdrop.hidden = false;
      drawer.querySelector("input")?.focus();
      return;
    }

    setTimeout(() => {
      if (!backdrop.classList.contains("is-open")) {
        backdrop.hidden = true;
      }
    }, 180);
  };

  const clearLoginHash = () => {
    if (window.location.hash !== LOGIN_HASH) {
      return;
    }
    const cleanUrl = `${window.location.pathname}${window.location.search}`;
    window.history.replaceState(null, "", cleanUrl);
  };

  const syncLoginFromHash = () => {
    setLoginOpen(window.location.hash === LOGIN_HASH);
  };

  openButton.addEventListener("click", () => {
    if (window.location.hash !== LOGIN_HASH) {
      window.location.hash = "login";
      return;
    }
    setLoginOpen(true);
  });

  closeButtons.forEach((button) => {
    button.addEventListener("click", () => {
      clearLoginHash();
      setLoginOpen(false);
    });
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      clearLoginHash();
      setLoginOpen(false);
    }
  });

  window.addEventListener("hashchange", syncLoginFromHash);
  syncLoginFromHash();
});
