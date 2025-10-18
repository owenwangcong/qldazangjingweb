import { Metadata } from 'next';
import { readFileSync } from 'fs';
import { join } from 'path';
import JuanDetailPage from './JuanDetailPage';

// Define the type for the structure of mlsData
type JuanData = {
  id: string;
  name: string;
  bus: {
    id: string;
    name: string;
    href: string;
    bu: string;
    title: string;
    author: string;
    volume: string;
  }[];
};

// Helper function to load mls data
async function loadMlsData(): Promise<Record<string, JuanData>> {
  const filePath = join(process.cwd(), 'public', 'data', 'mls.json');
  const fileContents = readFileSync(filePath, 'utf8');
  return JSON.parse(fileContents);
}

// Generate metadata for SEO
export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const { id } = params;
  const siteUrl = "https://www.qldazangjing.com";

  try {
    const mlsData = await loadMlsData();
    // Find the juan data
    const juan = (Object.values(mlsData) as JuanData[]).find((item) => item.id === id);

    if (juan) {
      const description = `${juan.name}，收录${juan.bus.length}部经书。来自清代乾隆年间编纂的乾隆大藏经目录。`;
      const bookTitles = juan.bus.slice(0, 5).map(b => b.title).join("、");

      return {
        title: juan.name,
        description: description,
        keywords: [juan.name, "大藏经目录", "经书目录", "佛经", "Buddhist Scripture Index"],
        alternates: {
          canonical: `/juans/${id}`,
        },
        openGraph: {
          title: `${juan.name} | 乾隆大藏经`,
          description: description,
          url: `${siteUrl}/juans/${id}`,
          type: "website",
          locale: "zh_CN",
          siteName: "乾隆大藏经",
        },
        twitter: {
          card: "summary",
          title: `${juan.name} | 乾隆大藏经`,
          description: description,
        },
        other: {
          "application/ld+json": JSON.stringify([
            {
              "@context": "https://schema.org",
              "@type": "CollectionPage",
              "name": juan.name,
              "description": description,
              "inLanguage": "zh-CN",
              "url": `${siteUrl}/juans/${id}`,
              "isPartOf": {
                "@type": "Collection",
                "name": "乾隆大藏经",
                "url": siteUrl
              },
              "numberOfItems": juan.bus.length,
              "hasPart": juan.bus.slice(0, 10).map(book => ({
                "@type": "Book",
                "name": book.title,
                "author": {
                  "@type": "Person",
                  "name": book.author
                },
                "url": `${siteUrl}/books/${book.id}`
              }))
            },
            {
              "@context": "https://schema.org",
              "@type": "BreadcrumbList",
              "itemListElement": [
                {
                  "@type": "ListItem",
                  "position": 1,
                  "name": "首页",
                  "item": siteUrl
                },
                {
                  "@type": "ListItem",
                  "position": 2,
                  "name": juan.name,
                  "item": `${siteUrl}/juans/${id}`
                }
              ]
            }
          ])
        },
      };
    }
  } catch (error) {
    console.error('Failed to load mls data:', error);
  }

  return {
    title: '找不到卷',
    description: '请求的卷不存在。',
    robots: {
      index: false,
      follow: false,
    }
  };
}

// Server-side page component
const Page = async ({ params }: { params: { id: string } }) => {
  const { id } = params;

  try {
    const mlsData = await loadMlsData();
    // Fetch the Juan data
    const juan = (Object.values(mlsData) as JuanData[]).find((item) => item.id === id);

    // Pass the data to the client-side component
    return <JuanDetailPage juan={juan} />;
  } catch (error) {
    console.error('Failed to load mls data:', error);
    return <div>Error loading juan data</div>;
  }
};

export default Page;
