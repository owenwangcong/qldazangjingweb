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

  // Search mode: 'title' or 'fulltext'
  const [searchMode, setSearchMode] = useState<'title' | 'fulltext'>('title');

  // New state to track search button clicks
  const [isSearchClicked, setIsSearchClicked] = useState<boolean>(false);

  // Total results for Elasticsearch
  const [totalResults, setTotalResults] = useState<number>(0);

  // Pagination states
  const [currentPage, setCurrentPage] = useState<number>(1);
  const itemsPerPage = 10;
  const totalPages = searchMode === 'fulltext'
    ? Math.ceil(totalResults / itemsPerPage)
    : Math.ceil(filteredBooks.length / itemsPerPage);

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
  const handleSearch = async () => {
    setIsSearchClicked(true);
    setLoading(true);
    setError(null);
    const term = searchTerm.trim();

    if (term === '') {
      setFilteredBooks([]);
      setTotalResults(0);
      setLoading(false);
      return;
    }

    try {
      if (searchMode === 'title') {
        // Local search by title/author
        const converter = OpenCC.Converter({ from: 'tw', to: 'cn' });
        const simplifiedTerm = converter(term);
        const lowerTerm = simplifiedTerm.toLowerCase();
        const filtered = books.filter(book =>
          book.title.toLowerCase().includes(lowerTerm) ||
          book.author.toLowerCase().includes(lowerTerm)
        );
        setFilteredBooks(filtered);
        setTotalResults(filtered.length);
      } else {
        // Full text search using Elasticsearch
        const converter = OpenCC.Converter({ from: 'tw', to: 'cn' });
        const simplifiedTerm = converter(term);

        const response = await fetch('/api/elasticsearch/search', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            query: simplifiedTerm,
            originalQuery: term,
            mode: 'smart',
            fields: ['title', 'author', 'content'],
            from: (currentPage - 1) * itemsPerPage,
            size: itemsPerPage,
            highlight: true
          }),
        });

        if (!response.ok) {
          throw new Error('Search request failed');
        }

        const data = await response.json();

        if (data.error) {
          throw new Error(data.error);
        }

        // Map Elasticsearch results to Book format
        const results = data.hits.map((hit: any) => ({
          id: hit.id,
          bu: '',
          title: hit.title || '',
          author: hit.author || '',
          highlights: hit.highlights
        }));

        setFilteredBooks(results);
        setTotalResults(data.total);
      }
    } catch (err: any) {
      setError(err.message || 'Search failed');
      setFilteredBooks([]);
      setTotalResults(0);
    } finally {
      setLoading(false);
    }
  };

  // New handler to manage page changes
  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    if (searchMode === 'fulltext') {
      // Re-run search for new page in fulltext mode
      handleSearch();
    }
  };

  // Handle search mode change
  const handleSearchModeChange = (mode: 'title' | 'fulltext') => {
    setSearchMode(mode);
    setFilteredBooks([]);
    setTotalResults(0);
    setCurrentPage(1);
    setIsSearchClicked(false);
  };

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8">
        <h1 className="text-3xl font-bold"><Text>搜索经书</Text></h1>

        {/* Search Mode Toggle */}
        <div className="flex gap-4 mb-2">
          <button
            onClick={() => handleSearchModeChange('title')}
            className={classNames(
              'px-6 py-2 rounded-md font-medium transition-all',
              searchMode === 'title'
                ? 'bg-primary text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            )}
            aria-label="按标题搜索"
          >
            <Text>标题搜索</Text>
          </button>
          <button
            onClick={() => handleSearchModeChange('fulltext')}
            className={classNames(
              'px-6 py-2 rounded-md font-medium transition-all',
              searchMode === 'fulltext'
                ? 'bg-primary text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            )}
            aria-label="全文搜索"
          >
            <Text>全文搜索</Text>
          </button>
        </div>

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
              placeholder={searchMode === 'title' ? '输入经书名或作者' : '输入关键词或短语进行全文搜索'}
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

        {/* Search mode description */}
        <p className="text-sm text-gray-600 text-center max-w-md">
          {searchMode === 'title' ? (
            <Text>在经书标题和作者中搜索</Text>
          ) : (
            <Text>在经书全文内容中搜索关键词和短语</Text>
          )}
        </p>
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
