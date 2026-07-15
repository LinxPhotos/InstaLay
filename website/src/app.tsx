import { MetaProvider, Title } from "@solidjs/meta";
import { Router } from "@solidjs/router";
import { FileRoutes } from "@solidjs/start/router";
import { Suspense } from "solid-js";
import "./app.css";
import { SiteNav } from "./components/SiteNav";
import { SiteFooter } from "./components/SiteFooter";

export default function App() {
  return (
    <Router
      root={(props) => (
        <MetaProvider>
          <Title>InstaLay</Title>
          <div class="shell">
            <SiteNav />
            <main class="main">
              <Suspense>{props.children}</Suspense>
            </main>
            <SiteFooter />
          </div>
        </MetaProvider>
      )}
    >
      <FileRoutes />
    </Router>
  );
}
