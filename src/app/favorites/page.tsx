import React from 'react';
import Header from '@/app/components/Header';
import FavoritesList from './FavoritesList';

const FavoritesPage: React.FC = () => {
  return (
    <>
      <Header />
      <FavoritesList />
    </>
  );
};

export default FavoritesPage;
