"use client";

import React, { useState, useEffect } from 'react';
import Header from '@/app/components/Header';

const FavoritesPage: React.FC = () => {
  const [favorites, setFavorites] = useState<string[]>([]);
  return (
    <>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-10 gap-10 sm:p-10">
        <h1 className="text-3xl font-bold">收藏</h1>
        {favorites.length > 0 ? (
          <ul className="w-full max-w-4xl">
            {favorites.map((favorite, index) => (
              <li key={index} className="text-lg mt-2">
                {favorite}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-lg mt-2">No favorites yet.</p>
        )}
      </div>
    </>
  );
};

export default FavoritesPage;
