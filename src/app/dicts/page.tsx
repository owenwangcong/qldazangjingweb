import React from 'react';
import Header from '@/app/components/Header';

const DictsPage: React.FC = () => {
  return (
    <>
      <Header />
      <div className="flex justify-center items-center h-screen">
        <h1 className="text-3xl font-bold">Dictionary Page</h1>
      </div>
    </>
  );
};

export default DictsPage;
