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

  try {
    const bookMetaData = await loadBookMetaData();
    // Retrieve the book metadata by id
    const bookMeta: BookMeta | undefined = bookMetaData[id];

    if (bookMeta) {
      return {
        title: `${bookMeta.title}`,
        description: `经名: ${bookMeta.title}. 作者: ${bookMeta.author}`,
        other: {
          "application/ld+json": JSON.stringify({
            "@context": "https://schema.org",
            "@type": "Book",
            "name": bookMeta.title,
            "description": `经名: ${bookMeta.title}. 作者: ${bookMeta.author}`,
          }),
        },
      };
    }
  } catch (error) {
    console.error('Failed to load book metadata:', error);
  }

  return {
    title: '找不到经书',
    description: '请求的经书不存在。',
  };
}

// Server-side page component
const Page = ({ params }: { params: { id: string } }) => {
  const { id } = params;

  // Pass the metadata to the client-side component
  return <BookDetailPage/>;
};

export default Page;
