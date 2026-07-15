import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { BuyButton } from "../components/BuyButton";
import { LICENSE_PRODUCT } from "../lib/pricing";

export default function Home() {
  return (
    <>
      <Title>InstaLay — IG canvas without the stupid crop</Title>
      <section class="hero">
        <p class="muted">Batch frame · tapestry · every platform</p>
        <h1>InstaLay</h1>
        <p class="lede">
          Prepare photos for Instagram’s aspect-ratio limits without chopping
          the shot. Canvas mattes, pixel borders, Lanczos exports, and SCRL-style
          tapestry carousels — on Windows, macOS, Linux, Android, iOS, and web.
        </p>
        <div class="cta-row">
          <BuyButton />
          <A class="btn btn-ghost" href="/download">
            Download builds
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
            <h3>Own it once</h3>
            <p>
              {LICENSE_PRODUCT.name}: one payment covers every platform build you
              run.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
