'use client';

import type { Metadata } from "next";
import localFont from "next/font/local";
import Script from 'next/script';
import "./globals.css";
import { FontProvider } from './context/FontContext';
import { LanguageProvider } from './context/LanguageContext'; // Ensure LanguageProvider is imported
import FontWrapper from './components/FontWrapper'; // Ensure FontWrapper is imported
import { ThemeProvider } from './context/ThemeContext'; // Import ThemeProvider
import { useEffect } from 'react'; // Add this import
import { MyStudyProvider } from "./context/MyStudyContext";
import { Toaster } from "@/components/ui/toaster"
import { AnnotationProvider } from "./context/AnnotationContext";
import { usePathname } from "next/navigation";
import Head from 'next/head'; // Import Head from Next.js

const aakai = localFont({
    src: "../../public/website_fonts/aaKaiTi_website_text.woff",
    variable: "--font-aakai",
    weight: "100 900",
});
const aakaiSong = localFont({
    src: "../../public/website_fonts/aaKaiSong_website_text.woff",
    variable: "--font-aakaiSong",
    weight: "100 900",
});
const lxgw = localFont({
    src: "../../public/website_fonts/lxgw_website_text.woff",
    variable: "--font-lxgw",
    weight: "100 900",
});
const hyfs = localFont({
    src: "../../public/website_fonts/hyFangSong_website_text.woff",
    variable: "--font-hyfs",
    weight: "200 1000",
});
const qnlb = localFont({
    src: "../../public/website_fonts/qnBianLi_website_text.woff",
    variable: "--font-qnlb",
    weight: "100 900",
});
const rzykt = localFont({
    src: "../../public/website_fonts/rzyKaiTi_website_text.woff",
    variable: "--font-rzykt",
    weight: "100 900",
});
const twzk = localFont({
    src: "../../public/website_fonts/twZhengKai_website_text.woff",
    variable: "--font-twzk",
    weight: "100 900",
});
const wqwh = localFont({
    src: "../../public/website_fonts/wqwMiHei_website_text.woff",
    variable: "--font-wqwh",
    weight: "100 900",
});

/* export const metadata: Metadata = {
  title: "乾隆大藏经",
  description: "Generated by create next app",
};
 */

const GA_TRACKING_ID = 'G-YYK959RPCX';

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {

  const pathname = usePathname();
  const canonicalUrl = `https://qldazangjing.com${pathname}`;

  useEffect(() => {
    const handleRouteChange = (url: string) => {
      (window as any).gtag('config', GA_TRACKING_ID, {
        page_path: url,
      });
    };
    handleRouteChange(pathname);
  }, [pathname]);

  useEffect(() => { // Add this useEffect hook
    const handleContextMenu = (event: MouseEvent) => {
      event.preventDefault();
    };
    document.addEventListener('contextmenu', handleContextMenu);    
    return () => {
      document.removeEventListener('contextmenu', handleContextMenu);
    };
  }, []);

  return (
    <html lang="en">
      <head>
        <title>乾隆大藏经 | 大藏经</title>
        <link rel="canonical" href={canonicalUrl} />
        <Script
          src={`https://www.googletagmanager.com/gtag/js?id=${GA_TRACKING_ID}`}
          strategy="afterInteractive"
        />
        <Script
          id="google-analytics"
          strategy="afterInteractive"
          dangerouslySetInnerHTML={{
            __html: `
              window.dataLayer = window.dataLayer || [];
              function gtag(){dataLayer.push(arguments);}
              gtag('js', new Date());
              gtag('config', '${GA_TRACKING_ID}', {
                page_path: window.location.pathname,
              });
              gtag('event', 'conversion', { 'send_to': 'AW-819400923/KyMeCKbag-oZENuh3IYD', 'value': 1.0, 'currency': 'CAD' });
            `,
          }}
        />
        <link rel="stylesheet" href="/styles/recogito.min.css" />
        <link rel="preload" href="/scripts/opencc.min.js" as="script" />
      </head>
      <body className={`antialiased ${aakai.variable} ${aakaiSong.variable} ${lxgw.variable} ${hyfs.variable} ${qnlb.variable} ${rzykt.variable} ${twzk.variable} ${wqwh.variable}`}>
        <Script src="/scripts/opencc.min.js" strategy="beforeInteractive" />
        <AnnotationProvider>
          <MyStudyProvider>
            <FontProvider>
              <LanguageProvider>
                <ThemeProvider>
                  <FontWrapper>
                    {children}
                  </FontWrapper>
                </ThemeProvider>
              </LanguageProvider>
            </FontProvider>
          </MyStudyProvider>
        </AnnotationProvider>
        <Toaster />
      </body>
    </html>
  );
}
