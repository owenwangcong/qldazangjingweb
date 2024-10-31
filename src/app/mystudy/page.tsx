"use client";

import React, { useEffect, useState } from 'react';
import Header from '@/app/components/Header';
import { useMyStudy } from '@/app/context/MyStudyContext';
import mlsData from '../../../public/data/mls.json';
import Text from '@/app/components/Text';
import Link from 'next/link';
import Pagination from '../components/Pagination';

interface Book {
    id: string;
  title: string;
}

const MyStudyPage: React.FC = () => {
  const {
    favoriteBooks,
    removeFavoriteBook,
    browserHistory,
    bookmarks,
    removeBookmark,
  } = useMyStudy();

  const [allBooks, setAllBooks] = useState<Book[]>([]);

  useEffect(() => {
    const books = Object.values(mlsData).flatMap(section => section.bus);
    setAllBooks(books);
  }, []);

    // Pagination for favorites
    const [currentFavoritePage, setCurrentFavoritePage] = useState<number>(1);
    const itemsPerFavoritePage = 10;
    const [totalFavoritePages, setTotalFavoritePages] = useState<number>(1);
    const [currentFavorites, setCurrentFavorites] = useState<string[]>([]);
    const handleFavoritePageChange = (page: number) => {
        setCurrentFavoritePage(page);
    };
    useEffect(() => {
      setTotalFavoritePages(Math.ceil(favoriteBooks.length / itemsPerFavoritePage));
      setCurrentFavorites(
        favoriteBooks.slice(
          (currentFavoritePage - 1) * itemsPerFavoritePage,
          currentFavoritePage * itemsPerFavoritePage
        )
      );
    }, [favoriteBooks, currentFavoritePage]);

    // Pagination for hitsory
    const [currentHistoryPage, setCurrentHistoryPage] = useState<number>(1);
    const itemsPerHistoryPage = 5;
    const [totalHistoryPages, setTotalHistoryPages] = useState<number>(1);
    const [currentHistory, setCurrentHistory] = useState<string[]>([]);
    const handleHistoryPageChange = (page: number) => {
        setCurrentHistoryPage(page);
    };
    useEffect(() => {
      setTotalHistoryPages(Math.ceil(browserHistory.length / itemsPerHistoryPage));
      setCurrentHistory(
        browserHistory.slice(
          (currentHistoryPage - 1) * itemsPerHistoryPage,
          currentHistoryPage * itemsPerHistoryPage
        )
      );
    }, [browserHistory, currentHistoryPage]);

    // Pagination for bookmarks
    const [currentBookmarkPage, setCurrentBookmarkPage] = useState<number>(1);
    const itemsPerBookmarkPage = 2;
    const [totalBookmarkPages, setTotalBookmarkPages] = useState<number>(1);
    const [currentBookmarks, setCurrentBookmarks] = useState<string[]>([]);
    const handleBookmarkPageChange = (page: number) => {
        setCurrentBookmarkPage(page);
    };  
    useEffect(() => {
      setTotalBookmarkPages(Math.ceil(bookmarks.length / itemsPerBookmarkPage));
      setCurrentBookmarks(
        bookmarks.slice(
          (currentBookmarkPage - 1) * itemsPerBookmarkPage,
          currentBookmarkPage * itemsPerBookmarkPage
        )
      );
    }, [bookmarks, currentBookmarkPage]);

  return (
    <>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8 sm:p-8">
        <div className="w-full max-w-4xl">
            {/* 收藏 */}
            <h1 className="text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>收藏</Text></h1>
            {currentFavorites.length > 0 ? (
                allBooks
                .filter((book: Book) => currentFavorites.includes(book.id))
                .map((book: Book, bookIndex: number) => (
                    <div key={book.id} className="flex justify-between items-center p-2 m-2 border border-border rounded shadow hover:bg-primary-hover transition">
                        <Link href={`/books/${book.id}`} className="flex-grow text-left focus:outline-none focus:ring-2 focus:ring-primary"><Text>{book.title}</Text></Link>
                            <button
                              className="min-w-[2rem] text-destructive cursor-pointer"
                              aria-label="删除"
                              onClick={() => removeFavoriteBook(book.id)}
                            >
                              <Text>删除</Text>
                            </button>
                    </div>
                ))
                ) : (
                    <div className="flex justify-center items-center p-2 m-2">
                        <Text>暂无收藏</Text>
                    </div>
            )}
            <Pagination
                currentPage={currentFavoritePage}
                totalPages={totalFavoritePages}
                onPageChange={handleFavoritePageChange}
            />

            {/* 历史 */}
            <h1 className="text-2xl font-bold flex justify-center p-2 m-2 mt-16 bg-secondary"><Text>历史</Text></h1>
            {currentHistory.length > 0 ? (
                allBooks
                .filter((book: Book) => currentHistory.includes(book.id))
                .map((book: Book, bookIndex: number) => (
                    <div key={book.id} className="flex justify-between items-center p-2 m-2 border border-border rounded shadow hover:bg-primary-hover transition">
                        <Link href={`/books/${book.id}`} className="flex-grow text-left focus:outline-none focus:ring-2 focus:ring-primary"><Text>{book.title}</Text></Link>
                    </div>
                ))
                ) : (
                    <div className="flex justify-center items-center p-2 m-2">
                        <Text>暂无历史</Text>
                    </div>
            )}
            <Pagination
                currentPage={currentHistoryPage}
                totalPages={totalHistoryPages}
                onPageChange={handleHistoryPageChange}
            />

            {/* 书签 */}
            <h1 className="text-2xl font-bold flex justify-center p-2 m-2 mt-16 bg-secondary"><Text>书签</Text></h1>
            {currentBookmarks.length > 0 ? (
                allBooks
                .filter((book: Book) => currentBookmarks.includes(book.id))
                .map((book: Book, bookIndex: number) => (
                    <div key={book.id} className="flex justify-between items-center p-2 m-2 border border-border rounded shadow hover:bg-primary-hover transition">
                        <Link href={`/books/${book.id}`} className="flex-grow text-left focus:outline-none focus:ring-2 focus:ring-primary"><Text>{book.title}</Text></Link>
                    </div>
                ))
                ) : (
                    <div className="flex justify-center items-center p-2 m-2">
                        <Text>暂无书签</Text>
                    </div>
            )}      
            <Pagination
                currentPage={currentBookmarkPage}
                totalPages={totalBookmarkPages}
                onPageChange={handleBookmarkPageChange}
            />
        </div>
      </div>
    </>
  );
};

export default MyStudyPage; 