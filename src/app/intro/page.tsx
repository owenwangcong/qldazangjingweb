import { Metadata } from 'next';
import IntroPageClient from './IntroPageClient';

export async function generateMetadata(): Promise<Metadata> {
  const siteUrl = "https://www.qldazangjing.com";
  const description = "了解乾隆大藏经网站的功能和使用方法。本站提供佛教经典的在线阅读、全文搜索、辞典查询、注释和研究功能。";

  return {
    title: "网站简介",
    description: description,
    keywords: ["网站简介", "使用说明", "功能介绍", "乾隆大藏经介绍", "Introduction"],
    alternates: {
      canonical: "/intro",
    },
    openGraph: {
      title: "网站简介 | 乾隆大藏经",
      description: description,
      url: `${siteUrl}/intro`,
      type: "website",
      locale: "zh_CN",
      siteName: "乾隆大藏经",
    },
    twitter: {
      card: "summary",
      title: "网站简介 | 乾隆大藏经",
      description: description,
    },
    other: {
      "application/ld+json": JSON.stringify({
        "@context": "https://schema.org",
        "@type": "AboutPage",
        "name": "网站简介",
        "description": description,
        "url": `${siteUrl}/intro`,
        "inLanguage": "zh-CN",
        "isPartOf": {
          "@type": "WebSite",
          "name": "乾隆大藏经",
          "url": siteUrl
        }
      })
    }
  };
}

export default function IntroPage() {
  return <IntroPageClient />;
}