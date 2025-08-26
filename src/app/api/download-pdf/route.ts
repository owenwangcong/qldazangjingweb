import logger from '@/app/utils/logger';
import { NextRequest, NextResponse } from 'next/server';
import puppeteer from 'puppeteer';

export async function POST(req: NextRequest) {
  const userIp = req.headers.get('x-forwarded-for') || req.ip || 'Unknown IP';
  const userAgent = req.headers.get('user-agent') || 'Unknown';
  const method = req.method;
  const requestUrl = req.url;

  let browser = null;
  let page = null;

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
          '--single-process',
          '--disable-gpu'
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
        if (isSimplified !== undefined) localStorage.setItem('isSimplified', isSimplified.toString());
        if (selectedFont && selectedFont.trim() !== '') localStorage.setItem('selectedFont', selectedFont);
        if (selectedWidth && selectedWidth.trim() !== '') localStorage.setItem('selectedWidth', selectedWidth);
        if (theme && theme.trim() !== '') localStorage.setItem('theme', theme);
    }, fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme);

    logger.debug('Navigating to URL', { url }, userIp);
    await page.goto(url, { 
      waitUntil: 'networkidle0',
      timeout: 60000 
    });
    
    logger.debug('Waiting for content to render', {}, userIp);
    // Wait for the content to be rendered
    await page.waitForSelector('#recogito-container', { timeout: 30000 });
    
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
    });

    logger.debug('Generating PDF', {}, userIp);
    const startPdfTime = Date.now();
    const pdf = await page.pdf({
      format: 'A4',
      margin: {
        top: '0mm',
        bottom: '0mm',
        left: '0mm',
        right: '0mm'
      },
      printBackground: true,
      timeout: 120000
    });
    const pdfGenerationTime = Date.now() - startPdfTime;

    await browser.close();
    browser = null;

    logger.log(`POST /download-pdf - PDF generated successfully (${pdfGenerationTime}ms, ${Math.round(pdf.length / 1024)}KB)`, userIp, userAgent, method, requestUrl);

    // Return the PDF as a blob
    return new NextResponse(pdf, {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': 'attachment; filename=book.pdf'
      }
    });

  } catch (error: any) {
    // Clean up browser if still open
    if (browser) {
      try {
        await browser.close();
      } catch (closeError) {
        logger.warn('Failed to close browser during error cleanup', userIp, userAgent, method, requestUrl);
      }
    }

    logger.error('POST /download-pdf - PDF generation failed', error, userIp, userAgent, method, requestUrl);
    
    return NextResponse.json({ 
      error: 'Failed to generate PDF',
      details: error.message,
      timestamp: new Date().toISOString(),
      requestId: Math.random().toString(36).substring(7)
    }, { status: 500 });
  }
}
