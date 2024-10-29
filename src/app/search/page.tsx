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
          <div className="w-full flex flex-col sm:flex-row items-center">
            <input
              type="text"
              value={searchTerm}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  handleSearch();
                }
              }}
              onChange={handleSearchChange}
              className="w-full pl-3 pr-4 py-2 border border-border rounded-md bg-background font-sans mb-3 sm:mb-0 sm:mr-3"
              placeholder="输入经书名或作者"
              aria-label="搜索经书"
            />
            <button
              onClick={handleSearch}
              className="px-4 py-2 w-full sm:w-32 bg-primary text-white rounded-md hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary"
              aria-label="触发搜索"
            >
              <Text>搜索</Text>
            </button>
          </div>
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
                      <div className="flex flex-col sm:flex-row w-full">
                        <span className="text-xl font-medium text-foreground flex-grow sm:flex-grow-0 text-center sm:text-left" style={{ flexBasis: '55%' }}>
                          <Text>{book.title}</Text>
                        </span>
                        <span className="text-md text-muted-foreground flex-none text-center hidden sm:block" style={{ flexBasis: '20%' }}>
                          <Text>{book.bu}</Text>
                        </span>
                        <span className="text-md text-muted-foreground flex-none text-center" style={{ flexBasis: '25%' }}>
                          <Text>{book.author}</Text>
                        </span>
                      </div>
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
            {/* Pagination Controls */}
            <div className="w-full flex items-center mt-6">
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
              <div className="flex flex-nowrap justify-center space-x-2 flex-1 mx-4">
                {(() => {
                  const pages = [];
                  const total = totalPages;
                  const current = currentPage;
                  const delta = 1;
                  
                  const startPage = Math.max(2, current - delta);
                  const endPage = Math.min(total - 1, current + delta);
                  
                  for (let i = startPage; i <= endPage; i++) {
                    pages.push(i);
                  }
                  
                  if (startPage > 2) {
                    pages.unshift(
                      <button
                        key={1}
                        onClick={() => handlePageSelect(1)}
                        className={classNames(
                          'px-3 py-1 rounded-md',
                          currentPage === 1
                            ? 'bg-primary text-primary-foreground'
                            : 'bg-muted text-muted-foreground hover:bg-muted-foreground-hover'
                        )}
                        aria-label={`第 1 页`}
                      >
                        1
                      </button>
                    );
                    pages.splice(1, 0,
                      <span key="start-ellipsis" className="px-3 py-1 text-gray-500" aria-hidden="true">
                        ...
                      </span>
                    );
                  } else {
                    for (let i = 1; i < startPage; i++) {
                      pages.unshift(i);
                    }
                  }
                  
                  if (endPage < total -1) {
                    pages.push(
                      <span key="end-ellipsis" className="px-3 py-1 text-gray-500" aria-hidden="true">
                        ...
                      </span>
                    );
                    pages.push(
                      <button
                        key={total}
                        onClick={() => handlePageSelect(total)}
                        className={classNames(
                          'px-3 py-1 rounded-md',
                          currentPage === total
                            ? 'bg-primary text-primary-foreground'
                            : 'bg-muted text-muted-foreground hover:bg-muted-foreground-hover'
                        )}
                        aria-label={`第 ${total} 页`}
                      >
                        {total}
                      </button>
                    );
                  } else {
                    for (let i = endPage +1; i <= total; i++) {
                      pages.push(i);
                    }
                  }
                  
                  return pages.map((page, index) => {
                    if (typeof page === 'number') {
                      return (
                        <button
                          key={page}
                          onClick={() => handlePageSelect(page)}
                          className={classNames(
                            'px-3 py-1 rounded-md',
                            currentPage === page
                              ? 'bg-primary text-primary-foreground'
                              : 'bg-muted text-muted-foreground hover:bg-muted-foreground-hover'
                          )}
                          aria-label={`第 ${page} 页`}
                        >
                          {page}
                        </button>
                      );
                    } else {
                      return page;
                    }
                  });
                })()}
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
