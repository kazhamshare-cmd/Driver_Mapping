const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
  });

  const page = await browser.newPage();

  // A4サイズ (210mm x 297mm) をピクセルに変換 (96dpi想定で2倍の解像度)
  const width = 1587; // 210mm * 3.78 * 2
  const height = 2245; // 297mm * 3.78 * 2

  await page.setViewport({ width, height, deviceScaleFactor: 2 });

  const htmlPath = path.resolve(__dirname, 'flyer.html');
  await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });

  // 表面をスクリーンショット
  const frontElement = await page.$('.page.front');
  await frontElement.screenshot({
    path: path.resolve(__dirname, 'flyer_front.png'),
    type: 'png'
  });
  console.log('表面を保存しました: flyer_front.png');

  // 裏面をスクリーンショット
  const backElement = await page.$('.page.back');
  await backElement.screenshot({
    path: path.resolve(__dirname, 'flyer_back.png'),
    type: 'png'
  });
  console.log('裏面を保存しました: flyer_back.png');

  await browser.close();
  console.log('変換完了！');
})();
