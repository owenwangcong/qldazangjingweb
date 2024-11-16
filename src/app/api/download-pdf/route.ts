import logger from '@/app/utils/logger';
import { NextResponse } from 'next/server';
import puppeteer from 'puppeteer';

export async function POST(req: Request) {
  try {
    const { url, fontFamily, fontSize, isSimplified, selectedFont, selectedWidth, theme } = await req.json();
    
    const browser = await puppeteer.launch({
        headless: true,
        args: [
            '--disable-features=SameSiteByDefaultCookies',
            '--disable-features=CookiesWithoutSameSiteMustBeSecure',
            '--disable-site-isolation-trials'
        ]
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
    console.error('PDF generation error:', error);
    return NextResponse.json({ error: 'Failed to generate PDF' }, { status: 500 });
  }
}
