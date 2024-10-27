import React from 'react';
import Header from '@/app/components/Header';
import BookDetail from './BookDetail';
import { AnnotationProvider } from '@/app/context/AnnotationContext';
import mlsData from '@/app/data/mls.json';

const fetchBookIds = async (): Promise<string[]> => {
  const firstLevelElements = Object.values(mlsData);
  const bus = firstLevelElements.map(element => element.bus);
  const ids = bus.flatMap(busArray => busArray.map(bus => bus.id));
  return ids;
};

export async function generateStaticParams(): Promise<{ id: string }[]> {
  const ids = await fetchBookIds(); // Replace with actual data fetching logic

  // Return an array of params
  return ids.map(id => ({ id }));
};

const BookDetailPage: React.FC = () => {
  return (
    <>
      <Header />
      <BookDetail />
    </>
  );
};

export default () => (
  <AnnotationProvider>
    <BookDetailPage />
  </AnnotationProvider>
);
