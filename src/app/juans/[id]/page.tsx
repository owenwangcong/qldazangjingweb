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

  try {
    const mlsData = await loadMlsData();
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
  } catch (error) {
    console.error('Failed to load mls data:', error);
  }

  return {
    title: 'Juan not found',
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
