import { Metadata } from 'next';
import { readFileSync } from 'fs';
import { join } from 'path';
import BookDetailPage from './BookDetailPage';

// Define the type for book metadata
type BookMeta = {
  title: string;
  author: string;
};

// Define the type for the structure of bookMetaData
type BookMetaData = {
  [key: string]: BookMeta;
};

// Helper function to load book metadata
async function loadBookMetaData(): Promise<BookMetaData> {
  const filePath = join(process.cwd(), 'public', 'data', 'bookMetaData.json');
  const fileContents = readFileSync(filePath, 'utf8');
  return JSON.parse(fileContents);
}

// Generate metadata for SEO
export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const { id } = params;
  const siteUrl = "https://www.qldazangjing.com";

  try {
    const bookMetaData = await loadBookMetaData();
    // Retrieve the book metadata by id
    const bookMeta: BookMeta | undefined = bookMetaData[id];

    if (bookMeta) {
      const description = `${bookMeta.title}，作者：${bookMeta.author}。来自清代乾隆年间编纂的乾隆大藏经，在线阅读佛教经典原文。`;

      return {
        title: bookMeta.title,
        description: description,
        keywords: [bookMeta.title, bookMeta.author, "佛经", "大藏经", "乾隆大藏经", "Buddhist Scripture"],
        authors: [{ name: bookMeta.author }],
        alternates: {
          canonical: `/books/${id}`,
        },
        openGraph: {
          title: `${bookMeta.title} | 乾隆大藏经`,
          description: description,
          url: `${siteUrl}/books/${id}`,
          type: "article",
          locale: "zh_CN",
          siteName: "乾隆大藏经",
          authors: [bookMeta.author],
        },
        twitter: {
          card: "summary_large_image",
          title: `${bookMeta.title} | 乾隆大藏经`,
          description: description,
        },
        other: {
          "application/ld+json": JSON.stringify([
            {
              "@context": "https://schema.org",
              "@type": "Book",
              "name": bookMeta.title,
              "author": {
                "@type": "Person",
                "name": bookMeta.author
              },
              "description": description,
              "inLanguage": "zh-CN",
              "publisher": {
                "@type": "Organization",
                "name": "乾隆大藏经"
              },
              "url": `${siteUrl}/books/${id}`,
              "isPartOf": {
                "@type": "Collection",
                "name": "乾隆大藏经",
                "url": siteUrl
              }
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
                  "name": bookMeta.title,
                  "item": `${siteUrl}/books/${id}`
                }
              ]
            }
          ])
        },
      };
    }
  } catch (error) {
    console.error('Failed to load book metadata:', error);
  }

  return {
    title: '找不到经书',
    description: '请求的经书不存在。',
    robots: {
      index: false,
      follow: false,
    }
  };
}

// Server-side page component
const Page = ({ params }: { params: { id: string } }) => {
  const { id } = params;

  // Pass the metadata to the client-side component
  return <BookDetailPage/>;
};

export default Page;
