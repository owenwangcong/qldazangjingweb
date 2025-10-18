import { Metadata } from 'next';
import SearchPageClient from './SearchPageClient';

export async function generateMetadata(): Promise<Metadata> {
  const siteUrl = "https://www.qldazangjing.com";
  const description = "在乾隆大藏经中搜索佛教经典、论著和注疏。支持全文搜索和标题搜索，快速查找您需要的佛教文献内容。";

  return {
    title: "搜索经书",
    description: description,
    keywords: ["搜索", "佛经搜索", "大藏经搜索", "全文搜索", "经文检索", "Buddhist Scripture Search"],
    alternates: {
      canonical: "/search",
    },
    openGraph: {
      title: "搜索经书 | 乾隆大藏经",
      description: description,
      url: `${siteUrl}/search`,
      type: "website",
      locale: "zh_CN",
      siteName: "乾隆大藏经",
    },
    twitter: {
      card: "summary",
      title: "搜索经书 | 乾隆大藏经",
      description: description,
    },
    other: {
      "application/ld+json": JSON.stringify({
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": "搜索经书",
        "description": description,
        "url": `${siteUrl}/search`,
        "inLanguage": "zh-CN",
        "isPartOf": {
          "@type": "WebSite",
          "name": "乾隆大藏经",
          "url": siteUrl
        },
        "potentialAction": {
          "@type": "SearchAction",
          "target": {
            "@type": "EntryPoint",
            "urlTemplate": `${siteUrl}/search?q={search_term_string}`
          },
          "query-input": "required name=search_term_string"
        }
      })
    }
  };
}

const Page = () => {
  return <SearchPageClient />;
};

export default Page;
