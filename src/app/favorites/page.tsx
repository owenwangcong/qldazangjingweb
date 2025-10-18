import { Metadata } from 'next';
import FavoritesPageClient from './FavoritesPageClient';

export async function generateMetadata(): Promise<Metadata> {
  return {
    title: "收藏",
    description: "查看您收藏的佛教经典。",
    robots: {
      index: false,
      follow: false,
    },
  };
}

export default function FavoritesPage() {
  return <FavoritesPageClient />;
}
