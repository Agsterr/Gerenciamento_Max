// Gera as artes das lojas a partir das capturas em raw/.
// Uso: node compose.mjs <pasta-raw>   (requer `npm i playwright`; CHROMIUM=/caminho opcional)
import { chromium } from "playwright";
import { mkdirSync, readFileSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const raw = resolve(process.argv[2] ?? join(here, "raw"));
const store = resolve(here, "..");
const plan = JSON.parse(readFileSync(join(here, "screens.json"), "utf8"));

const SIZES = {
  ios: { w: 1320, h: 2868, dir: (app) => join(store, app, "ios", "screenshots", "pt-BR") },        // iPhone 6.9"
  android: { w: 1080, h: 1920, dir: (app) => join(store, app, "android", "pt-BR", "images", "phoneScreenshots") },
};

const b = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
for (const [app, screens] of Object.entries(plan)) {
  for (const [platform, size] of Object.entries(SIZES)) {
    const dir = size.dir(app);
    if (existsSync(dir)) rmSync(dir, { recursive: true });
    mkdirSync(dir, { recursive: true });
    const page = await b.newPage({ viewport: { width: size.w, height: size.h } });
    for (const [i, s] of screens.entries()) {
      const params = new URLSearchParams({
        w: size.w, h: size.h, theme: app, title: s.title, subtitle: s.subtitle,
        img: pathToFileURL(join(raw, s.file)).href, top: s.top, status: s.status,
      });
      await page.goto(pathToFileURL(join(here, "frame.html")).href + "?" + params);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForFunction(() => document.getElementById("shot").complete);
      await page.screenshot({ path: join(dir, `${i + 1}_${s.file}`) });
    }
    await page.close();
  }
}
// Arte de destaque (Play Store, 1024x500) e ícone 512x512
const FEATURE = {
  cliente: { title: "Seu horário de beleza em 1 minuto", subtitle: "Agende sem cadastro, só com nome e WhatsApp", s1: "c3-salao.png", s2: "c5-confirmado.png" },
  gestao: { title: "A agenda do seu salão, organizada", subtitle: "Agenda, clientes, estoque e lucro", s1: "g1-agenda.png", s2: "g3-financeiro.png" },
};
for (const [app, f] of Object.entries(FEATURE)) {
  const images = join(store, app, "android", "pt-BR", "images");
  mkdirSync(images, { recursive: true });
  const icon = join(store, "..", app, "assets", "icon.png");
  const page = await b.newPage({ viewport: { width: 1024, height: 500 } });
  const params = new URLSearchParams({
    theme: app, title: f.title, subtitle: f.subtitle,
    icon: pathToFileURL(icon).href, s1: pathToFileURL(join(raw, f.s1)).href, s2: pathToFileURL(join(raw, f.s2)).href,
  });
  await page.goto(pathToFileURL(join(here, "feature.html")).href + "?" + params);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForFunction(() => [...document.images].every((i) => i.complete));
  await page.screenshot({ path: join(images, "featureGraphic.png") });
  await page.setViewportSize({ width: 512, height: 512 });
  await page.setContent(`<body style="margin:0"><img src="${pathToFileURL(icon).href}" style="width:512px;height:512px;display:block"></body>`);
  await page.waitForFunction(() => document.images[0].complete);
  await page.screenshot({ path: join(images, "icon.png") });
  await page.close();
}
await b.close();
console.log("artes geradas em", store);
