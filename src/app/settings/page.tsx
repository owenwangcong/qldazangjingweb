import { Metadata } from 'next';

export async function generateMetadata(): Promise<Metadata> {
  return {
    title: "设置",
    description: "个人设置页面。",
    robots: {
      index: false,
      follow: false,
    },
  };
}

import React from 'react';
import Header from '@/app/components/Header';

const SettingsPage: React.FC = () => {
  return (
    <>
      <Header />
      <div className="flex justify-center items-center h-screen">
        <h1 className="text-3xl font-bold">Settings Page</h1>
      </div>
    </>
  );
};

export default SettingsPage;
