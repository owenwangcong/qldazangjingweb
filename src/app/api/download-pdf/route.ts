import logger from '@/app/utils/logger';
import { NextRequest, NextResponse } from 'next/server';
import puppeteer from 'puppeteer';

export async function POST(req: NextRequest) {
  const userIp = req.headers.get('x-forwarded-for') || req.ip || 'Unknown IP';

  try {
    const { url, fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme } = await req.json();
    
    logger.log(`PDF generation started for URL: ${url}`, userIp);
    logger.log(`Font Family: ${fontFamily}`, userIp);
    logger.log(`Font Size: ${fontSize}`, userIp);
    logger.log(`Is Simplified: ${isSimplified}`, userIp);
    logger.log(`Selected Font: ${selectedFont}`, userIp);
    logger.log(`Selected Width: ${selectedWidth}`, userIp);
    logger.log(`Theme: ${theme}`, userIp);

    const browser = await puppeteer.launch({
        headless: true,
    });
    
    const page = await browser.newPage();

    await page.evaluateOnNewDocument((fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme) => {
        if (fontFamily && fontFamily.trim() !== '') localStorage.setItem('fontFamily', fontFamily);
        if (fontSize && fontSize.trim() !== '') localStorage.setItem('fontSize', fontSize);
        if (isSimplified !== undefined) localStorage.setItem('isSimplified', isSimplified.toString());
        if (selectedFont && selectedFont.trim() !== '') localStorage.setItem('selectedFont', selectedFont);
        if (selectedWidth && selectedWidth.trim() !== '') localStorage.setItem('selectedWidth', selectedWidth);
        if (theme && theme.trim() !== '') localStorage.setItem('theme', theme);
    }, fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme);

    await page.goto(url, { waitUntil: 'networkidle0' });
    
    // Wait for the content to be rendered
    await page.waitForSelector('#recogito-container');
    
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

    const pdf = await page.pdf({
      format: 'A4',
      margin: {
        top: '0mm',
        bottom: '0mm',
        left: '0mm',
        right: '0mm'
      },
      printBackground: true,
    });

    await browser.close();

    // Return the PDF as a blob
    return new NextResponse(pdf, {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': 'attachment; filename=book.pdf'
      }
    });

  } catch (error) {
    logger.log(`PDF generation error: ${error}`, userIp);
    console.error('PDF generation error:', error);
    return NextResponse.json({ error: 'Failed to generate PDF' }, { status: 500 });
  }
}
