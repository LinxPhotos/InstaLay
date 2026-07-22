import { createHandler, StartServer } from "@solidjs/start/server";
import { THEME_BOOTSTRAP } from "./lib/theme";

const faviconHref = `${import.meta.env.BASE_URL || "/"}instalay_logo.svg`.replace(
  /([^:]\/)\/+/g,
  "$1",
);

export default createHandler(() => (
  <StartServer
    document={({ assets, children, scripts }) => (
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta
            name="description"
            content="InstaLay — batch Instagram canvas, tapestry layouts. Free to use; buy yearly or lifetime to support the developer."
          />
          <link rel="icon" href={faviconHref} type="image/svg+xml" />
          {/* Apply system theme before paint to avoid a light FOUC. */}
          <script innerHTML={THEME_BOOTSTRAP} />
          {assets}
        </head>
        <body>
          <div id="app">{children}</div>
          {scripts}
        </body>
      </html>
    )}
  />
));
