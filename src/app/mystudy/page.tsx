import { Metadata } from 'next';
import MyStudyPageClient from './MyStudyPageClient';

export async function generateMetadata(): Promise<Metadata> {
  const siteUrl = "https://www.qldazangjing.com";
  const description = "管理您的个人学习资料，包括收藏的经书、阅读历史、书签和注释。方便您随时继续学习和研究佛教经典。";

  return {
    title: "我的书房",
    description: description,
    keywords: ["我的书房", "收藏", "阅读历史", "书签", "注释", "个人学习", "My Study"],
    alternates: {
      canonical: "/mystudy",
    },
    openGraph: {
      title: "我的书房 | 乾隆大藏经",
      description: description,
      url: `${siteUrl}/mystudy`,
      type: "website",
      locale: "zh_CN",
      siteName: "乾隆大藏经",
    },
    twitter: {
      card: "summary",
      title: "我的书房 | 乾隆大藏经",
      description: description,
    },
    robots: {
      index: false,
      follow: true,
    },
    other: {
      "application/ld+json": JSON.stringify({
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        "name": "我的书房",
        "description": description,
        "url": `${siteUrl}/mystudy`,
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
  return <MyStudyPageClient />;
};

export default Page;
