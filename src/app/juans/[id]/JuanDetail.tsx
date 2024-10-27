// src/app/components/JuanDetail.tsx
"use client";

import React from 'react';
import { useParams } from 'next/navigation';
import mlsData from '@/app/data/mls.json';
import Text from '@/app/components/Text';

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

const JuanDetail: React.FC = () => {
  const { id } = useParams();

  // Logic to find the specific Juan
  const juan = Object.values(mlsData).find((item) => item.id === id);

  if (!juan) {
    return (
      <div className="flex justify-center items-center h-screen">
        <h1 className="text-3xl font-bold">Juan not found</h1>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center min-h-screen p-8 pb-10 gap-16 sm:p-10">
      <h1 className="text-3xl font-bold">{juan.name}</h1>
      <div className="w-full max-w-4xl">
        <ul className="space-y-4">
          {juan.bus.map((busItem) => (
            <li key={busItem.id} className="p-4 border border-border rounded-lg shadow-md hover:bg-primary-hover transition">
              <a href={`/books/${busItem.id}`} className="flex justify-between items-center">
                <span className="text-xl font-medium text-foreground flex-grow" style={{ flexBasis: '55%' }}>
                  <Text>{busItem.title}</Text>
                </span>
                <span className="text-md text-muted-foreground flex-none text-center" style={{ flexBasis: '20%' }}>
                  <Text>{busItem.bu}</Text>
                </span>
                <span className="text-md text-muted-foreground flex-none text-center" style={{ flexBasis: '25%' }}>
                  <Text>{busItem.author}</Text>
                </span>
              </a>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default JuanDetail;