import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { DownloadCta } from "../components/DownloadCta";
import { LINX } from "../lib/linx";
import { EDITIONS } from "../lib/pricing";
import { BuyButton } from "../components/BuyButton";

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
          Prepare your photos for Instagram on Desktop and Mobile, without
          awkward cropping. Our app uses a Canvas layer to allow positioning your photos
          carefully on a background matte, the way an artist or professional photographer would.
          Optionally change the matte texture and color, and add pixel borders.
          Get creative by converting your photos into a tapestry layout
          like SCRL carousels. Compatible with Windows, macOS, Linux, Android, iOS, and web.
        </p>
        <div class="cta-row">
          <A class="btn btn-primary" href="/docs/pricing">
            Pricing
          </A>
          <BuyButton plan="lifetime" label="Buy on Linx Photos" />
          <DownloadCta owner="LinxPhotos" repo="InstaLay" label="Download Free" />
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

      <section class="section linx-funnel">
        <h2>InstaLay integrates with your LinxPhotos library, optionally.</h2>
        <p class="lede">
          InstaLay is a stand-alone tool, but it can edit photos you've saved on our hosting service, {" "}
          <a href={LINX.home} rel="noopener noreferrer">
            Linx Photos
          </a>{" "}. 
          Linx Photos coordinates with InstaLay prepare Instagram layouts from your photos.
        </p>
        <div class="cta-row">
          <a class="btn btn-primary" href={LINX.instalayBuy} rel="noopener noreferrer">
            Buy InstaLay on Linx
          </a>
          <a class="btn btn-ghost" href={LINX.login} rel="noopener noreferrer">
            Log in
          </a>
          <A class="btn btn-ghost" href="/docs">
            InstaLay docs
          </A>
        </div>
      </section>
    </>
  );
}
