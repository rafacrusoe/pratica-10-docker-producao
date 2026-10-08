const { chromium } = require("playwright");

async function capture(page, url, path) {
  await page.goto(url, { waitUntil: "networkidle" });
  await page.screenshot({ path, fullPage: true });
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1500, height: 1000 }, deviceScaleFactor: 1 });
  await capture(page, "http://127.0.0.1:3000", "evidencias/01-servico-transacoes.png");
  await capture(page, "http://127.0.0.1:5000", "evidencias/02-servico-consultas.png");
  await capture(page, `file://${process.cwd()}/evidencias/03-recursos.html`, "evidencias/03-recursos-producao.png");
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});

