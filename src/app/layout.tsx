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
    display: "swap",
});
const aakaiSong = localFont({
    src: "../../public/website_fonts/aaKaiSong_website_text.woff",
    variable: "--font-aakaiSong",
    weight: "100 900",
    display: "swap",
});
const lxgw = localFont({
    src: "../../public/website_fonts/lxgw_website_text.woff",
    variable: "--font-lxgw",
    weight: "100 900",
    display: "swap",
});
const hyfs = localFont({
    src: "../../public/website_fonts/hyFangSong_website_text.woff",
    variable: "--font-hyfs",
    weight: "200 1000",
    display: "swap",
});
const qnlb = localFont({
    src: "../../public/website_fonts/qnBianLi_website_text.woff",
    variable: "--font-qnlb",
    weight: "100 900",
    display: "swap",
});
const rzykt = localFont({
    src: "../../public/website_fonts/rzyKaiTi_website_text.woff",
    variable: "--font-rzykt",
    weight: "100 900",
    display: "swap",
});
const twzk = localFont({
    src: "../../public/website_fonts/twZhengKai_website_text.woff",
    variable: "--font-twzk",
    weight: "100 900",
    display: "swap",
});
const wqwh = localFont({
    src: "../../public/website_fonts/wqwMiHei_website_text.woff",
    variable: "--font-wqwh",
    weight: "100 900",
    display: "swap",
});

const GA_TRACKING_ID = 'G-YYK959RPCX';

export async function generateMetadata(): Promise<Metadata> {
    const siteUrl = "https://www.qldazangjing.com";
    const description = "乾隆大藏经是清代乾隆年间编纂的一部重要佛教典籍，收录了大量佛教经典、论著和注疏。本网站提供乾隆大藏经的在线阅读、检索、注释和研究功能，让读者能够方便地查阅和学习这部珍贵的佛教文献。乾隆大藏经。龙藏。";

    return {
        metadataBase: new URL(siteUrl),
        title: {
            default: "乾隆大藏经 | 大藏经",
            template: "%s | 乾隆大藏经"
        },
        description: description,
        keywords: ["乾隆大藏经", "龙藏", "佛教典籍", "佛经", "大藏经", "佛教经典", "佛学", "Buddhist Scripture", "Qianlong Dazangjing"],
        authors: [{ name: "乾隆大藏经" }],
        creator: "乾隆大藏经",
        publisher: "乾隆大藏经",
        alternates: {
            canonical: "/",
            languages: {
                'zh-CN': '/',
                'zh-TW': '/',
            }
        },
        openGraph: {
            type: "website",
            locale: "zh_CN",
            url: siteUrl,
            siteName: "乾隆大藏经",
            title: "乾隆大藏经 | 大藏经",
            description: description,
        },
        twitter: {
            card: "summary_large_image",
            title: "乾隆大藏经 | 大藏经",
            description: description,
        },
        viewport: {
            width: "device-width",
            initialScale: 1,
            maximumScale: 5,
        },
        robots: {
            index: true,
            follow: true,
            googleBot: {
                index: true,
                follow: true,
                'max-video-preview': -1,
                'max-image-preview': 'large',
                'max-snippet': -1,
            },
        },
        other: {
            "application/ld+json": JSON.stringify([
                {
                    "@context": "https://schema.org",
                    "@type": "Organization",
                    "name": "乾隆大藏经",
                    "url": siteUrl,
                    "logo": `${siteUrl}/images/BELL.png`,
                    "description": "清代乾隆年间编纂的重要佛教典籍数字化平台",
                    "sameAs": []
                },
                {
                    "@context": "https://schema.org",
                    "@type": "WebSite",
                    "name": "乾隆大藏经",
                    "url": siteUrl,
                    "description": description,
                    "inLanguage": "zh-CN",
                    "potentialAction": {
                        "@type": "SearchAction",
                        "target": {
                            "@type": "EntryPoint",
                            "urlTemplate": `${siteUrl}/search?q={search_term_string}`
                        },
                        "query-input": "required name=search_term_string"
                    }
                }
            ])
        }
    };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {

  return (
    <html lang="zh-CN">
      <head>
        <link rel="preconnect" href="https://www.googletagmanager.com" />
        <link rel="dns-prefetch" href="https://www.google-analytics.com" />
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
