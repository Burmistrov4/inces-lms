import { chromium } from '@playwright/test';

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto('http://127.0.0.1:3000/login');
  await page.fill('input[type="text"]', 'lorenzo-roca11@hotmail.com');
  await page.fill('input[type="password"]', 'Codenamelms33$');
  await page.click('button[type="submit"]');
  await page.waitForURL('**/operaciones', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/cierre_ciclo_produccion/04a_admin_pizarra_mural_mtp_pna.png' });
  console.log('Pizarra Mural updated screenshot taken!');
  await browser.close();
}

main().catch(console.error);
