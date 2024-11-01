"use client";

import React, { useState, useEffect } from 'react';
import Header from '@/app/components/Header';
import Link from 'next/link';
import { Search as SearchIcon, ChevronLeft, ChevronRight } from 'lucide-react';
import classNames from 'classnames';
import Text from '@/app/components/Text';
import Pagination from '@/app/components/Pagination';
import * as OpenCC from 'opencc-js';

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
  const totalPages = Math.ceil(filteredBooks.length / itemsPerPage);

  // Calculate currentBooks for the current page
  const currentBooks = filteredBooks.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

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
    setIsSearchClicked(true);
    const term = searchTerm.trim();

    // Dynamically import OpenCC using require
    const converter = OpenCC.Converter({ from: 'tw', to: 'cn' });
    const simplifiedTerm = converter(term);
    
    if (term === '') {
      setFilteredBooks([]);
      return;
    }

    const lowerTerm = simplifiedTerm.toLowerCase();
    const filtered = books.filter(book =>
      book.title.toLowerCase().includes(lowerTerm) ||
      book.author.toLowerCase().includes(lowerTerm)
    );
    setFilteredBooks(filtered);
  };

  // New handler to manage page changes
  const handlePageChange = (page: number) => {
    setCurrentPage(page);
  };

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-10 gap-8 sm:p-10">
        <h1 className="text-3xl font-bold"><Text>搜索经书</Text></h1>
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
            {/* Use Pagination component */}
            <Pagination
              currentPage={currentPage}
              totalPages={totalPages}
              onPageChange={handlePageChange}
            />
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
