// Gera os PNGs dos ícones a partir dos SVGs: node render-icons.mjs  (requer `npm i playwright`)
import { chromium } from "playwright";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const svg = (n) => readFileSync(join(here, n), "utf8");
const b = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
const page = await b.newPage({ viewport: { width: 1024, height: 1024 } });

async function render(layers, out, { transparent = false, scale = 1, mono = false } = {}) {
  const html = `<html><body style="margin:0;background:transparent">
    <div style="position:relative;width:1024px;height:1024px">
      ${layers
        .map((l, i) => {
          const s = i === layers.length - 1 ? scale : 1;
          const style = `position:absolute;inset:0;transform:scale(${s});${mono && i === layers.length - 1 ? "filter:brightness(0) invert(1);" : ""}`;
          return `<div style="${style}">${l.replace("<svg ", '<svg width="1024" height="1024" ')}</div>`;
        })
        .join("")}
    </div></body></html>`;
  await page.setContent(html);
  await page.screenshot({ path: out, omitBackground: transparent, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
}

for (const app of ["cliente", "gestao"]) {
  const assets = join(here, "..", app, "assets");
  const bg = svg(`background-${app}.svg`), sym = svg(`symbol-${app}.svg`);
  await render([bg, sym], join(assets, "icon.png"));                                  // iOS / legado / lojas
  await render([bg], join(assets, "icon_background.png"));                            // adaptativo: fundo
  await render([sym], join(assets, "icon_foreground.png"), { transparent: true, scale: 0.72 }); // zona segura 66%
  const flat = sym.replace(/ filter="url\(#sh\)"/g, "");
  await render([flat], join(assets, "icon_monochrome.png"), { transparent: true, scale: 0.72, mono: true }); // Android 13 temático
}
await b.close();
console.log("ícones gerados");
