"use client";

import React, { useState, useEffect } from 'react';
import Header from './components/Header';
import Link from 'next/link';
import { FontContext } from './context/FontContext';
import Text from '@/app/components/Text';
import $ from 'jquery';
import Head from 'next/head';

interface MlsItem {
  id: string;
  name: string;
}

type MlsData = Record<string, MlsItem>;

export default function Home() {
  const [mlsData, setMlsData] = useState<MlsData>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadMlsData = async () => {
      try {
        const response = await fetch('/data/mls.json');
        const data = await response.json();
        setMlsData(data);
      } catch (error) {
        console.error('Failed to load mls data:', error);
      } finally {
        setLoading(false);
      }
    };

    loadMlsData();
  }, []);

  if (loading) {
    return (
      <>
        <Header />
        <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8">
          <div className="text-center">Loading...</div>
        </div>
      </>
    );
  }

  return (
    <> 
      <Header />
      <div 
        className={`flex flex-col items-center min-h-screen p-8 pb-8 gap-8`}
      >
        <main 
          id="annotatable-content" 
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-2 xl:grid-cols-2 gap-8 items-start"
        >
          {Object.entries(mlsData).map(([key, { id, name }]) => (
                // Start of Selection
                <Link
                  key={key}
                  href={`/juans/${id}`}
                  passHref
                  className="p-4 border border-border rounded-lg shadow-md w-full max-w-md block hover:bg-primary-hover transition-colors"
                >
                  <h2 className="text-xl font-semibold text-center text-foreground"><Text>{name}</Text></h2>
                </Link>
          ))}
        </main>
        <footer className="flex gap-6 flex-wrap items-center justify-center">
          {/* Footer content */}
        </footer>
      </div>
    </>
  );
}
