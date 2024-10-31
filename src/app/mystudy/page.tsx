"use client";

import React, { useEffect, useState } from 'react';
import Header from '@/app/components/Header';
import { FavoriteBook, BrowserHistoryItem, Bookmark, useMyStudy } from '@/app/context/MyStudyContext';
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
    const [currentFavorites, setCurrentFavorites] = useState<FavoriteBook[]>([]);
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
    const [currentHistory, setCurrentHistory] = useState<BrowserHistoryItem[]>([]);
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
    const itemsPerBookmarkPage = 10;
    const [totalBookmarkPages, setTotalBookmarkPages] = useState<number>(1);
    const [currentBookmarks, setCurrentBookmarks] = useState<Bookmark[]>([]);
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

        <div className="flex flex-col space-y-4 sm:flex-row sm:space-y-0 sm:space-x-4">
            <Link href="#favorite" className="border border-primary rounded-full hover:border-primary-hover transition">
                <Text className="m-5">收藏</Text>
            </Link>
            <Link href="#history" className="border border-primary rounded-full hover:border-primary-hover transition">
                <Text className="m-5">历史</Text>
            </Link>
            <Link href="#bookmark" className="border border-primary rounded-full hover:border-primary-hover transition">
                <Text className="m-5">书签</Text>
            </Link>
            <Link href="#bookmark" className="border border-primary rounded-full hover:border-primary-hover transition">
                <Text className="m-5">注释</Text>
            </Link>
        </div>

        <div className="w-full max-w-4xl">
            {/* 收藏 */}
            <h1 id="favorite" className="text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>收藏</Text></h1>
            {currentFavorites.length > 0 ? (
                allBooks
                .filter((book: Book) => currentFavorites.some(fav => fav.bookId === book.id))
                .sort((a, b) => {
                    const timestampA = currentFavorites.find(fav => fav.bookId === a.id)?.timestamp || 0;
                    const timestampB = currentFavorites.find(fav => fav.bookId === b.id)?.timestamp || 0;
                    return timestampB - timestampA;
                })
                .map((book: Book) => (
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
            <h1 id="history" className="text-2xl font-bold flex justify-center p-2 m-2 mt-16 bg-secondary"><Text>历史</Text></h1>
            {currentHistory.length > 0 ? (
                allBooks
                .filter((book: Book) => currentHistory.some(history => history.bookId === book.id))
                .sort((a, b) => {
                    const timestampA = currentHistory.find(history => history.bookId === a.id)?.timestamp || 0;
                    const timestampB = currentHistory.find(history => history.bookId === b.id)?.timestamp || 0;
                    return timestampB - timestampA;
                })
                .map((book: Book) => (
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
            <h1 id="bookmark" className="text-2xl font-bold flex justify-center p-2 m-2 mt-16 bg-secondary"><Text>书签</Text></h1>
            {currentBookmarks.length > 0 ? (
                currentBookmarks.map((bookmark) => {
                    return (
                        <div key={bookmark.compositeKey} className="flex justify-between items-center p-2 m-2 border border-border rounded shadow hover:bg-primary-hover transition">
                            <Link 
                                href={`/books/${bookmark.bookId}/#${bookmark.partId}`} 
                                className="flex-grow text-left focus:outline-none focus:ring-2 focus:ring-primary font-sans"
                            >
                                <Text>{allBooks.find((book: Book) => book.id === bookmark.bookId)?.title || '未知书籍'}</Text>
                                <Text>{bookmark.content}</Text> 
                                <Text>...</Text>
                            </Link>
                            <button
                                className="min-w-[2rem] text-destructive cursor-pointer"
                                onClick={() => removeBookmark(bookmark.bookId, bookmark.partId)}
                            >
                                <Text>删除</Text>
                            </button>
                        </div>
                    );
                })
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

            {/* 注释 */}
            <h1 id="annotation" className="text-2xl font-bold flex justify-center p-2 m-2 mt-16 bg-secondary"><Text>注释</Text></h1>
        </div>
      </div>
    </>
  );
};

export default MyStudyPage; 