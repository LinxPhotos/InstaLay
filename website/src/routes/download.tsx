import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { DownloadCta } from "../components/DownloadCta";
import { LINX } from "../lib/linx";

export default function DownloadPage() {
  return (
    <article class="prose">
      <Title>Download — InstaLay</Title>
      <h1>Download</h1>
      <p>
        Get InstaLay for Windows, macOS, or Linux, then install it. InstaLay Free
        is the same app as InstaLay — to support the developer,{" "}
        <A href="/support">donate</A>, or{" "}
        <A href="/docs/pricing">buy a license</A>.
      </p>
      <DownloadCta
        owner="LinxPhotos"
        repo="InstaLay"
        label="Download InstaLay"
        anchor="download"
        platformFirst
      />
      <h2>Install</h2>
      <h3>Windows</h3>
      <ul>
        <li>
          <strong>Installer</strong>: run the <code>*-windows-*-setup.exe</code> from
          the download above. A portable ZIP and a Store MSIX ship on the same
          release.
        </li>
        <li>
          <strong>winget</strong> (after package acceptance):{" "}
          <code>winget install LinxPhotos.InstaLay</code>
        </li>
        <li>
          <strong>Microsoft Store</strong>: search “InstaLay”, or sideload the{" "}
          <code>*-store.msix</code> from Releases via Partner Center.
        </li>
      </ul>
      <h3>macOS</h3>
      <p>
        Open the <code>*-macos-*.dmg</code> from the download above, or{" "}
        <code>brew install --cask amdphreak/tap/instalay</code>.
      </p>
      <h3>Linux</h3>
      <p>
        Extract the <code>*-linux-*.tar.gz</code> for your CPU and run{" "}
        <code>./instalay</code>.
      </p>
      <h3>Mobile and web</h3>
      <p>
        Android, iOS, and web builds ship from the same Flutter project. Store
        listings use the keyword pack in <code>store/</code>.
      </p>
      <p class="muted">
        Pair InstaLay with{" "}
        <a href={LINX.home} rel="noopener noreferrer">
          Linx Photos
        </a>{" "}
        to pull album variants into tapestry projects and publish from your
        hosted library.
      </p>
    </article>
  );
}