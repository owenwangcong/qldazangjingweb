import logger from '@/app/utils/logger';
import { NextRequest, NextResponse } from 'next/server';
import puppeteer from 'puppeteer';

// --- Concurrency guard -------------------------------------------------------
// Each puppeteer.launch() spawns a headless Chromium tree that can use
// 300MB-1GB+ RSS. On this shared, memory-constrained box, running several at
// once exhausts RAM, spills into swap, and can OOM-kill the host. So we allow
// only ONE PDF render at a time and cap how many may wait; excess requests get
// 429 instead of piling up browsers (and hanging clients) indefinitely.
const MAX_CONCURRENT = 1;
const MAX_QUEUED = 3;
let active = 0;
let queued = 0;
const waiters: Array<() => void> = [];

async function acquireSlot(): Promise<boolean> {
  if (active < MAX_CONCURRENT) {
    active++;
    return true;
  }
  if (queued >= MAX_QUEUED) {
    return false; // too busy — shed load
  }
  queued++;
  await new Promise<void>((resolve) => waiters.push(resolve));
  // Slot was transferred to us by releaseSlot(); `active` already accounts for it.
  return true;
}

function releaseSlot(): void {
  const next = waiters.shift();
  if (next) {
    queued--;
    // Hand the active slot directly to the next waiter (active count unchanged).
    next();
  } else {
    active--;
  }
}
// -----------------------------------------------------------------------------

export async function POST(req: NextRequest) {
  const userIp = req.headers.get('x-forwarded-for') || req.ip || 'Unknown IP';
  const userAgent = req.headers.get('user-agent') || 'Unknown';
  const method = req.method;
  const requestUrl = req.url;

  let browser = null;
  let page = null;

  // Backpressure: never let more than one Chromium run at once on this box.
  const gotSlot = await acquireSlot();
  if (!gotSlot) {
    logger.warn('POST /download-pdf - rejected (PDF render queue full)', userIp, userAgent, method, requestUrl);
    return NextResponse.json(
      { error: 'Server busy generating PDFs. Please retry shortly.' },
      { status: 429, headers: { 'Retry-After': '30' } }
    );
  }

  try {
    const { url, fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme } = await req.json();
    
    const pdfConfig = {
      url,
      fontFamily,
      fontSize,
      isSimplified,
      selectedFont,
      selectedWidth,
      theme
    };

    logger.log(`POST /download-pdf - PDF generation started`, userIp, userAgent, method, requestUrl);
    logger.debug('PDF generation config', pdfConfig, userIp);

    // Launch browser with enhanced error handling
    browser = await puppeteer.launch({
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--no-first-run',
          '--no-zygote',
          '--disable-gpu',
          '--disable-software-rasterizer',
          '--disable-extensions',
          '--max-old-space-size=4096'
        ]
    });

    logger.debug('Browser launched successfully', {}, userIp);
    
    page = await browser.newPage();

    // Set page settings
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Set timeout for page operations
    page.setDefaultTimeout(60000);

    await page.evaluateOnNewDocument((fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme) => {
        if (fontFamily && fontFamily.trim() !== '') localStorage.setItem('fontFamily', fontFamily);
        if (fontSize && fontSize.trim() !== '') localStorage.setItem('fontSize', fontSize);
        if (isSimplified !== undefined && isSimplified !== null) localStorage.setItem('isSimplified', String(isSimplified));
        if (selectedFont && selectedFont.trim() !== '') localStorage.setItem('selectedFont', selectedFont);
        if (selectedWidth && selectedWidth.trim() !== '') localStorage.setItem('selectedWidth', selectedWidth);
        if (theme && theme.trim() !== '') localStorage.setItem('theme', theme);
    }, fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme);

    logger.debug('Navigating to URL', { url }, userIp);
    await page.goto(url, {
      waitUntil: 'networkidle2',
      timeout: 90000
    });
    
    logger.debug('Waiting for content to render', {}, userIp);
    // Wait for the content to be rendered
    await page.waitForSelector('#recogito-container', { timeout: 30000 });

    // Additional wait to ensure fonts and images are loaded
    await page.evaluate(() => document.fonts.ready);
    await new Promise(resolve => setTimeout(resolve, 2000));

    logger.debug('Hiding header and footer elements', {}, userIp);
    // Hide the header element before generating PDF
    await page.evaluate(() => {
        const header = document.getElementById('header');
        if (header) {
            header.style.display = 'none';
        }
        const footer = document.getElementById('book-footer');
        if (footer) {
            footer.style.display = 'none';
        }

        // Add print-specific CSS to reduce gaps between pages
        const style = document.createElement('style');
        style.textContent = `
            @media print {
                @page {
                    margin: 0;
                }
                html, body {
                    margin: 0 !important;
                    padding: 0 !important;
                    height: auto !important;
                }
                #recogito-container {
                    padding: 20px !important;
                    margin: 0 !important;
                }
                h1, h2, h3, h4, h5, h6 {
                    page-break-after: avoid !important;
                    break-after: avoid !important;
                }
                p {
                    orphans: 3;
                    widows: 3;
                }
            }
        `;
        document.head.appendChild(style);
    });

    logger.debug('Generating PDF', {}, userIp);
    const startPdfTime = Date.now();
    const pdf = await page.pdf({
      format: 'A4',
      margin: {
        top: '10mm',
        bottom: '10mm',
        left: '15mm',
        right: '15mm'
      },
      printBackground: true,
      preferCSSPageSize: false,
      timeout: 120000
    });
    const pdfGenerationTime = Date.now() - startPdfTime;

    logger.log(`POST /download-pdf - PDF generated successfully (${pdfGenerationTime}ms, ${Math.round(pdf.length / 1024)}KB)`, userIp, userAgent, method, requestUrl);

    // Return the PDF as a blob
    return new NextResponse(pdf, {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': 'attachment; filename=book.pdf'
      }
    });

  } catch (error: any) {
    logger.error('POST /download-pdf - PDF generation failed', error, userIp, userAgent, method, requestUrl);

    return NextResponse.json({
      error: 'Failed to generate PDF',
      details: error.message,
      timestamp: new Date().toISOString(),
      requestId: Math.random().toString(36).substring(7)
    }, { status: 500 });
  } finally {
    // Always ensure browser is closed
    if (browser) {
      try {
        if (page && !page.isClosed()) {
          await page.close();
        }
        await browser.close();
      } catch (closeError) {
        logger.warn('Failed to close browser during cleanup', userIp, userAgent, method, requestUrl);
      }
    }
    // Always free the concurrency slot, even on early return / error.
    releaseSlot();
  }
}
