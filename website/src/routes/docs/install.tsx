import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";

export default function InstallDocs() {
  return (
    <article class="prose">
      <Title>Install — Insta Lay</Title>
      <h1>Install</h1>
      <h2>Windows</h2>
      <ul>
        <li>
          <strong>winget</strong> (after package acceptance):{" "}
          <code>winget install AMDphreak.InstaLay</code>
        </li>
        <li>
          <strong>Microsoft Store</strong>: search “Insta Lay” or sideload the{" "}
          <code>*-store.msix</code> from Releases via Partner Center.
        </li>
        <li>
          <strong>Portable / Inno</strong>: download the ZIP or setup EXE from{" "}
          <A href="/download">Downloads</A>.
        </li>
      </ul>
      <h2>macOS</h2>
      <p>
        <code>brew install --cask amdphreak/tap/insta-lay</code> or install the
        DMG/ZIP from Releases.
      </p>
      <h2>Linux</h2>
      <p>
        Extract the <code>.tar.gz</code> release bundle and run{" "}
        <code>./insta_lay</code>.
      </p>
      <h2>Mobile &amp; web</h2>
      <p>
        Android / iOS / web builds ship from the same Flutter project. Store
        listings use the keyword pack in <code>store/</code>.
      </p>
    </article>
  );
}
