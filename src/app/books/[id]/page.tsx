import { Metadata } from 'next';
import bookMetaData from '../../../../public/data/bookMetaData.json';
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

// Generate metadata for SEO
export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const { id } = params;

  // Retrieve the book metadata by id
  const bookMeta: BookMeta | undefined = (bookMetaData as BookMetaData)[id];

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

  return {
    title: '找不到经书',
    description: '请求的经书不存在。',
  };
}

// Server-side page component
const Page = ({ params }: { params: { id: string } }) => {
  const { id } = params;

  // Retrieve the book metadata by id
  //const bookMeta: BookMeta | undefined = (bookMetaData as BookMetaData)[id];

  // Pass the metadata to the client-side component
  return <BookDetailPage/>;
};

export default Page;
