import { Metadata } from 'next';

export async function generateMetadata(): Promise<Metadata> {
  return {
    title: "下载",
    description: "下载佛教经典PDF文档。",
    robots: {
      index: false,
      follow: false,
    },
  };
}

import React from 'react';
import Header from '@/app/components/Header';

const DownloadsPage: React.FC = () => {
  return (
    <>
      <Header />
      <div className="flex justify-center items-center h-screen">
        <h1 className="text-3xl font-bold">Downloads Page</h1>
      </div>
    </>
  );
};

export default DownloadsPage;
