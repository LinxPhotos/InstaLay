import { A, useLocation } from "@solidjs/router";
import { createEffect, createSignal, onCleanup, onMount } from "solid-js";
import { LINX } from "../lib/linx";
import { ThemeToggle } from "./ThemeToggle";

const logoSrc = `${import.meta.env.BASE_URL}instalay_logo.svg`.replace(
  /([^:]\/)\/+/g,
  "$1",
);

const NAV_COMPACT_MQ = "(max-width: 52rem)";

function MenuIcon() {
  return (
    <svg
      class="nav-menu-icon"
      viewBox="0 0 24 24"
      width="18"
      height="18"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      stroke-linecap="round"
    >
      <path d="M4 7h16M4 12h16M4 17h16" />
    </svg>
  );
}

function CloseIcon() {
  return (
    <svg
      class="nav-menu-icon"
      viewBox="0 0 24 24"
      width="18"
      height="18"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      stroke-linecap="round"
    >
      <path d="M6 6l12 12M18 6L6 18" />
    </svg>
  );
}

export function SiteNav() {
  const [open, setOpen] = createSignal(false);
  const location = useLocation();
  let navRef: HTMLElement | undefined;

  createEffect(() => {
    location.pathname;
    setOpen(false);
  });

  onMount(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    const onPointerDown = (e: PointerEvent) => {
      if (!open()) return;
      const target = e.target;
      if (target instanceof Node && navRef?.contains(target)) return;
      setOpen(false);
    };
    const mq = window.matchMedia(NAV_COMPACT_MQ);
    const onMq = () => {
      if (!mq.matches) setOpen(false);
    };

    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onPointerDown);
    mq.addEventListener("change", onMq);
    onCleanup(() => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onPointerDown);
      mq.removeEventListener("change", onMq);
    });
  });

  const closeMenu = () => setOpen(false);

  return (
    <header
      class="nav"
      classList={{ "nav-open": open() }}
      ref={(el) => {
        navRef = el;
      }}
    >
      <A href="/" class="brand" onClick={closeMenu}>
        <img
          src={logoSrc}
          alt=""
          width="28"
          height="28"
          class="brand-mark"
        />
        InstaLay
      </A>
      <div class="nav-end">
        <button
          type="button"
          class="nav-menu-toggle"
          aria-expanded={open()}
          aria-controls="site-nav-links"
          aria-label={open() ? "Close menu" : "Open menu"}
          onClick={() => setOpen((v) => !v)}
        >
          {open() ? <CloseIcon /> : <MenuIcon />}
        </button>
        <ul
          id="site-nav-links"
          class="nav-links"
          classList={{ "is-open": open() }}
        >
          <li>
            <A href="/docs" onClick={closeMenu}>
              Docs
            </A>
          </li>
          <li>
            <A href="/docs/pricing" onClick={closeMenu}>
              Pricing
            </A>
          </li>
          <li>
            <A href="/docs/install" onClick={closeMenu}>
              Install
            </A>
          </li>
          <li>
            <A href="/download" onClick={closeMenu}>
              Download
            </A>
          </li>
          <li>
            <A href="/buy" onClick={closeMenu}>
              Buy InstaLay
            </A>
          </li>
          <li>
            <a href={LINX.home} rel="noopener noreferrer" onClick={closeMenu}>
              Linx Photos
            </a>
          </li>
        </ul>
        <ThemeToggle />
      </div>
    </header>
  );
}
