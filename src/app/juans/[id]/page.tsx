import React from 'react';
import Header from '@/app/components/Header';
import JuanDetail from './JuanDetail';
import { GetStaticPaths } from 'next';
import mlsData from '@/app/data/mls.json';

const fetchJuanIds = async (): Promise<string[]> => {
  const firstLevelElements = Object.values(mlsData);
  const ids = firstLevelElements.map(element => element.id);
  return ids;
};

export async function generateStaticParams(): Promise<{ id: string }[]> {
  const ids = await fetchJuanIds(); // Replace with actual data fetching logic

  // Return an array of params
  return ids.map(id => ({ id }));
};

const JuanDetailPage: React.FC = () => {
  return (
    <>
      <Header />
      <JuanDetail />
    </>
  );
};

export default JuanDetailPage;
