"use client";

import React, { useState, useEffect } from 'react';
import Header from '@/app/components/Header';
import Link from 'next/link';
import { Search as SearchIcon, ChevronLeft, ChevronRight } from 'lucide-react';
import classNames from 'classnames';
import Text from '@/app/components/Text';

interface BusItem {
  id: string;
  name: string;
  href: string;
  bu: string;
  title: string;
  author: string;
  volume: string;
}

interface MlsEntry {
  id: string;
  name: string;
  bus: BusItem[];
}

interface Book {
  id: string;
  name: string;
  href: string;
  bu: string;
  title: string;
  author: string;
  volume: string;
}

const SearchPage: React.FC = () => {
  const [books, setBooks] = useState<Book[]>([]);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [filteredBooks, setFilteredBooks] = useState<Book[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  
  // New state to track search button clicks
  const [isSearchClicked, setIsSearchClicked] = useState<boolean>(false);
  
  // Pagination states
  const [currentPage, setCurrentPage] = useState<number>(1);
  const itemsPerPage = 10;
  
  // Calculate total pages
  const totalPages = Math.ceil(filteredBooks.length / itemsPerPage);
  
  // Get current page books
  const indexOfLastBook = currentPage * itemsPerPage;
  const indexOfFirstBook = indexOfLastBook - itemsPerPage;
  const currentBooks = filteredBooks.slice(indexOfFirstBook, indexOfLastBook);

  // Fetch and parse mls.json data
  useEffect(() => {
    const fetchBooks = async () => {
      setLoading(true);
      try {
        const response = await fetch('/data/mls.json');
        if (!response.ok) {
          throw new Error(`Failed to fetch data: ${response.statusText}`);
        }
        const data: { [key: string]: MlsEntry } = await response.json();
        const allBooks: Book[] = [];
        Object.values(data).forEach(entry => {
          entry.bus.forEach(book => {
            allBooks.push(book);
          });
        });
        setBooks(allBooks);
      } catch (err: any) {
        setError(err.message || 'Unknown error');
      } finally {
        setLoading(false);
      }
    };

    fetchBooks();
  }, []);

  // Handle search input changes
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const term = e.target.value;
    setSearchTerm(term);
  };

  // Handle search trigger
  const handleSearch = () => {
    setIsSearchClicked(true); // Track search button click
    const term = searchTerm.trim();
    setCurrentPage(1); // Reset to first page on search

    if (term === '') {
      setFilteredBooks([]);
      return;
    }

    const lowerTerm = term.toLowerCase();
    const filtered = books.filter(book =>
      book.title.toLowerCase().includes(lowerTerm) ||
      book.author.toLowerCase().includes(lowerTerm)
    );
    setFilteredBooks(filtered);
  };

  // Handle page navigation
  const handlePrevious = () => {
    setCurrentPage(prev => Math.max(prev - 1, 1));
  };

  const handleNext = () => {
    setCurrentPage(prev => Math.min(prev + 1, totalPages));
  };

  const handlePageSelect = (page: number) => {
    setCurrentPage(page);
  };

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-10 gap-8 sm:p-10">
        <h1 className="text-3xl font-bold">搜索经书</h1>
        <div className="w-full max-w-md flex items-center">
          <SearchIcon className="mr-3 text-muted-foreground" />
          <input
            type="text"
            value={searchTerm}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                handleSearch();
              }
            }}
            onChange={handleSearchChange}
            className="w-full pl-3 pr-4 py-2 border border-border rounded-md bg-background font-sans"
            placeholder="输入经书名或作者"
            aria-label="搜索经书"
          />
          <button
            onClick={handleSearch}
            className="ml-3 px-4 py-2 w-32 bg-primary text-white rounded-md hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary"
            aria-label="触发搜索"
          >
            <Text>搜索</Text>
          </button>
        </div>
        {loading && <p className="mt-4 text-gray-600">加载中...</p>}
        {error && <p className="mt-4 text-red-500">错误: {error}</p>}
        {!loading && !error && filteredBooks.length > 0 && (
          <>
            <div className="w-full max-w-4xl">
              <ul className="space-y-4">
                {currentBooks.map(book => (
                  <li key={book.id} className="p-4 border border-border rounded-lg shadow-md hover:bg-primary-hover transition">
                    <Link href={`/books/${book.id}`} className="flex justify-between items-center">
                      <span className="text-xl font-medium text-foreground flex-grow" style={{ flexBasis: '55%' }}>
                        <Text>{book.title}</Text>
                      </span>
                      <span className="text-md text-muted-foreground flex-none text-center" style={{ flexBasis: '20%' }}>
                        <Text>{book.bu}</Text>
                      </span>
                      <span className="text-md text-muted-foreground flex-none text-center" style={{ flexBasis: '25%' }}>
                        <Text>{book.author}</Text>
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
            {/* Pagination Controls */}
            <div className="flex items-center mt-6">
              <button
                onClick={handlePrevious}
                disabled={currentPage === 1}
                className={classNames(
                  'p-2 rounded-md',
                  currentPage === 1
                    ? 'text-muted-foreground cursor-not-allowed'
                    : 'text-primary hover:bg-primary-hover'
                )}
                aria-label="上一页"
              >
                <ChevronLeft />
              </button>
              <div className="flex space-x-2 mx-4">
                {Array.from({ length: totalPages }, (_, index) => (
                  <button
                    key={index + 1}
                    onClick={() => handlePageSelect(index + 1)}
                    className={classNames(
                      'px-3 py-1 rounded-md',
                      currentPage === index + 1
                        ? 'bg-primary text-primary-foreground'
                        : 'bg-muted text-muted-foreground hover:bg-muted-foreground-hover'
                    )}
                    aria-label={`第 ${index + 1} 页`}
                  >
                    {index + 1}
                  </button>
                ))}
              </div>
              <button
                onClick={handleNext}
                disabled={currentPage === totalPages}
                className={classNames(
                  'p-2 rounded-md',
                  currentPage === totalPages
                    ? 'text-muted-foreground cursor-not-allowed'
                    : 'text-primary hover:bg-primary-hover'
                )}
                aria-label="下一页"
              >
                <ChevronRight />
              </button>
            </div>
          </>
        )}
        {!loading && !error && searchTerm.trim() !== '' && filteredBooks.length === 0 && isSearchClicked && (
          <p className="mt-4 text-gray-600">未找到匹配的经书</p>
        )}
      </div>
    </div>
  );
};

export default SearchPage;
