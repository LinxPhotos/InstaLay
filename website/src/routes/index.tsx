import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { BuyButton } from "../components/BuyButton";
import { EDITIONS } from "../lib/pricing";

const logoSrc = `${import.meta.env.BASE_URL}instalay_logo.svg`.replace(
  /([^:]\/)\/+/g,
  "$1",
);

export default function Home() {
  return (
    <>
      <Title>InstaLay — IG canvas without the stupid crop</Title>
      <section class="hero">
        <p class="muted">Batch frame · tapestry · every platform</p>
        <div class="hero-brand">
          <img
            src={logoSrc}
            alt=""
            width="64"
            height="64"
            class="hero-mark"
          />
          <h1>InstaLay</h1>
        </div>
        <p class="lede">
          Prepare photos for Instagram’s aspect-ratio limits without chopping
          the shot. Canvas mattes, pixel borders, Lanczos exports, and SCRL-style
          tapestry carousels — on Windows, macOS, Linux, Android, iOS, and web.
        </p>
        <div class="cta-row">
          <BuyButton plan="lifetime" />
          <A class="btn btn-ghost" href="/download">
            Download Free
          </A>
          <A class="btn btn-ghost" href="/docs">
            Read the docs
          </A>
        </div>
      </section>

      <section class="section">
        <h2>What you get</h2>
        <div class="grid-3">
          <div class="tile">
            <h3>No-crop canvas</h3>
            <p>4:5 and friends, letterboxed with photographic mattes and paper grain.</p>
          </div>
          <div class="tile">
            <h3>Tapestry mode</h3>
            <p>Stitch a panorama and slice it into carousel frames like SCRL.</p>
          </div>
          <div class="tile">
            <h3>{EDITIONS.paid.name}</h3>
            <p>
              {EDITIONS.paid.summary} Or use {EDITIONS.free.name} — same
              features either way.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
