import { Metadata } from 'next';
import DictsPageClient from './DictsPageClient';

export async function generateMetadata(): Promise<Metadata> {
  const siteUrl = "https://www.qldazangjing.com";
  const description = "查询佛教术语和词汇的含义。提供多部佛学辞典的释义，帮助您更好地理解佛教经典中的专业术语。";

  return {
    title: "佛学辞典",
    description: description,
    keywords: ["佛学辞典", "佛教词典", "佛教术语", "佛学词汇", "Buddhist Dictionary", "佛教名词解释"],
    alternates: {
      canonical: "/dicts",
    },
    openGraph: {
      title: "佛学辞典 | 乾隆大藏经",
      description: description,
      url: `${siteUrl}/dicts`,
      type: "website",
      locale: "zh_CN",
      siteName: "乾隆大藏经",
    },
    twitter: {
      card: "summary",
      title: "佛学辞典 | 乾隆大藏经",
      description: description,
    },
    other: {
      "application/ld+json": JSON.stringify({
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": "佛学辞典",
        "description": description,
        "url": `${siteUrl}/dicts`,
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

const Page = () => {
  return <DictsPageClient />;
};

export default Page;
