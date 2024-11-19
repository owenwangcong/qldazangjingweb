import type { Metadata } from "next";
import localFont from "next/font/local";
import Script from 'next/script';
import "./globals.css";
import Head from 'next/head';
import ClientProviders from './ClientProviders';

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

const GA_TRACKING_ID = 'G-YYK959RPCX';

export async function generateMetadata(): Promise<Metadata> {
    return {
        title: "乾隆大藏经 | 大藏经",
        description: "乾隆大藏经是清代乾隆年间编纂的一部重要佛教典籍，收录了大量佛教经典、论著和注疏。本网站提供乾隆大藏经的在线阅读、检索、注释和研究功能，让读者能够方便地查阅和学习这部珍贵的佛教文献。乾隆大藏经。龙藏。",
        openGraph: {
            title: "乾隆大藏经 | 大藏经",
            description: "乾隆大藏经是清代乾隆年间编纂的一部重要佛教典籍，收录了大量佛教经典、论著和注疏。本网站提供乾隆大藏经的在线阅读、检索、注释和研究功能，让读者能够方便地查阅和学习这部珍贵的佛教文献。乾隆大藏经。龙藏。",
            url: "https://www.qldazangjing.com",
        },
        twitter: {
            title: "乾隆大藏经 | 大藏经",
            description: "乾隆大藏经是清代乾隆年间编纂的一部重要佛教典籍，收录了大量佛教经典、论著和注疏。本网站提供乾隆大藏经的在线阅读、检索、注释和研究功能，让读者能够方便地查阅和学习这部珍贵的佛教文献。乾隆大藏经。龙藏。",
        },
    };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {

  return (
    <html lang="en">
      <head>
        <meta name="description" content="乾隆大藏经是清代乾隆年间编纂的一部重要佛教典籍，收录了大量佛教经典、论著和注疏。本网站提供乾隆大藏经的在线阅读、检索、注释和研究功能，让读者能够方便地查阅和学习这部珍贵的佛教文献。乾隆大藏经。龙藏。" />
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
        <ClientProviders>
          {children}
        </ClientProviders>
      </body>
    </html>
  );
}
