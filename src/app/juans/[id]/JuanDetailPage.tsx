"use client";

import React from 'react';
import Head from 'next/head';
import Header from '@/app/components/Header';
import Text from '@/app/components/Text';
import Link from 'next/link';

// Define types for props
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

type Props = {
  juan?: JuanData;
};

const JuanDetailPage: React.FC<Props> = ({ juan }) => {
  if (!juan) {
    return (
      <>
        <Head>
          <title>找不到卷</title>
        </Head>
        <Header />
        <div className="flex justify-center items-center h-screen">
          <h1 className="text-3xl font-bold">Juan not found</h1>
        </div>
      </>
    );
  }

  return (
    <>
      <Head>
        <title>{juan.name}</title>
      </Head>
      <Header />
      
      <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8">
        <h1 className="text-3xl font-bold">
          <Text>{juan.name}</Text>
        </h1>
        <div className="w-full max-w-4xl">
          <ul className="space-y-4">
            {juan.bus
              .filter((busItem) => !busItem.id.includes('ml'))
              .map((busItem) => (
                <li
                  key={busItem.id}
                  className="p-4 border border-border rounded-lg shadow-md hover:bg-primary-hover transition"
                >
                  <Link href={`/books/${busItem.id}`} className="flex justify-between items-center">
                    <div className="flex flex-col sm:flex-row w-full">
                      <span
                        className="text-xl font-medium text-foreground flex-grow sm:flex-grow-0 text-center sm:text-left"
                        style={{ flexBasis: '55%' }}
                      >
                        <Text>{busItem.title}</Text>
                      </span>
                      <span
                        className="text-md text-muted-foreground flex-none text-center hidden sm:block"
                        style={{ flexBasis: '20%' }}
                      >
                        <Text>{busItem.bu}</Text>
                      </span>
                      <span
                        className="text-md text-muted-foreground flex-none text-center"
                        style={{ flexBasis: '25%' }}
                      >
                        <Text>{busItem.author}</Text>
                      </span>
                    </div>
                  </Link>
                </li>
              ))}
          </ul>
        </div>
      </div>
    </>
  );
};

export default JuanDetailPage; 