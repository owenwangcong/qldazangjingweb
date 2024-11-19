import { Metadata } from 'next';
import mlsData from '../../../../public/data/mls.json';
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

// Generate metadata for SEO
export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const { id } = params;

  // Find the juan data
  const juan = (Object.values(mlsData) as JuanData[]).find((item) => item.id === id);

  if (juan) {
    return {
      title: juan.name,
      description: `卷名: ${juan.name}`,
      other: {
        "application/ld+json": JSON.stringify({
          "@context": "https://schema.org",
          "@type": "Book",
          "name": juan.name,
          "description": `卷名: ${juan.name}`,
        }),
      },
    };
  }

  return {
    title: 'Juan not found',
  };
}

// Server-side page component
const Page = ({ params }: { params: { id: string } }) => {
  const { id } = params;

  // Fetch the Juan data
  const juan = (Object.values(mlsData) as JuanData[]).find((item) => item.id === id);

  // Pass the data to the client-side component
  return <JuanDetailPage juan={juan} />;
};

export default Page;
