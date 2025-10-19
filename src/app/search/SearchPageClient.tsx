"use client";

import React, { useState, useEffect } from 'react';
import Header from '@/app/components/Header';
import Link from 'next/link';
import { Search as SearchIcon, ChevronLeft, ChevronRight } from 'lucide-react';
import Text from '@/app/components/Text';
import Pagination from '@/app/components/Pagination';
import * as OpenCC from 'opencc-js';
import { Checkbox } from '@/components/ui/checkbox';
import { Label } from '@/components/ui/label';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

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
  name?: string;
  href?: string;
  bu: string;
  title: string;
  author: string;
  volume: string;
  score?: number;
  highlights?: {
    title?: string[];
    author?: string[];
    content?: string[];
  };
}

const SearchPageClient: React.FC = () => {
  const [books, setBooks] = useState<Book[]>([]);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [filteredBooks, setFilteredBooks] = useState<Book[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // Search mode: 'title' or 'fulltext'
  const [searchMode, setSearchMode] = useState<'title' | 'fulltext'>('fulltext');

  // Phrase match mode for fulltext search
  const [usePhraseMatch, setUsePhraseMatch] = useState<boolean>(false);

  // New state to track search button clicks
  const [isSearchClicked, setIsSearchClicked] = useState<boolean>(false);

  // Total results for Elasticsearch
  const [totalResults, setTotalResults] = useState<number>(0);

  // Pagination states
  const [currentPage, setCurrentPage] = useState<number>(1);
  const itemsPerPage = 10;
  const maxPages = 50; // Limit to 50 pages (500 results max)
  const totalPages = Math.min(
    searchMode === 'fulltext'
      ? Math.ceil(totalResults / itemsPerPage)
      : Math.ceil(filteredBooks.length / itemsPerPage),
    maxPages
  );

  // Calculate currentBooks for the current page
  // For fulltext search, Elasticsearch already returns only the current page's results
  // For title search, we need to slice the local array
  const currentBooks = searchMode === 'fulltext'
    ? filteredBooks
    : filteredBooks.slice(
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
  const handleSearch = async (pageOverride?: number) => {
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

    // Use pageOverride if provided, otherwise use currentPage, default to 1
    const page = pageOverride ?? currentPage ?? 1;

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

        const fromValue = (page - 1) * itemsPerPage;
        console.log('Search params:', { page, itemsPerPage, from: fromValue });

        const response = await fetch('/api/elasticsearch/search', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            query: simplifiedTerm,
            originalQuery: term,
            mode: usePhraseMatch ? 'phrase' : 'smart',
            fields: ['title', 'author', 'content'],
            from: fromValue,
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
          volume: '',
          score: hit.score,
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
      // Re-run search for new page in fulltext mode with the new page number
      handleSearch(page);
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
        <Tabs
          value={searchMode}
          onValueChange={(value) => handleSearchModeChange(value as 'title' | 'fulltext')}
          className="w-full max-w-2xl"
        >
          <TabsList className="w-full">
            <TabsTrigger value="fulltext" className="flex-1">
              <Text>全文搜索</Text>
            </TabsTrigger>
            <TabsTrigger value="title" className="flex-1">
              <Text>标题搜索</Text>
            </TabsTrigger>
          </TabsList>

          {/* Tab content with border */}
          <div className="mt-4 p-6 border border-border rounded-lg bg-card">
            {/* Search mode description and options */}
            {searchMode === 'fulltext' && (
              <div className="flex items-center gap-2 mb-4">
                <Checkbox
                  id="phrase-match"
                  checked={usePhraseMatch}
                  onCheckedChange={(checked) => setUsePhraseMatch(checked as boolean)}
                />
                <Label
                  htmlFor="phrase-match"
                  className="text-sm text-gray-600 cursor-pointer"
                >
                  <Text>精确短语匹配（完整匹配搜索词）</Text>
                </Label>
              </div>
            )}

            <div className="flex flex-col sm:flex-row items-center gap-3">
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
                placeholder={searchMode === 'title' ? '输入经书名或作者' : '输入关键词或短语进行全文搜索'}
                aria-label="搜索经书"
              />
              <button
                onClick={() => handleSearch()}
                className="px-4 py-2 w-full sm:w-32 bg-primary text-white rounded-md hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary"
                aria-label="触发搜索"
              >
                <Text>搜索</Text>
              </button>
            </div>
          </div>
        </Tabs>
        {loading && <p className="mt-4 text-gray-600">加载中...</p>}
        {error && <p className="mt-4 text-red-500">错误: {error}</p>}
        {!loading && !error && filteredBooks.length > 0 && (
          <>
            <div className="w-full max-w-4xl">
              <ul className="space-y-4">
                {currentBooks.map(book => (
                  <li key={book.id} className="p-4 border border-border rounded-lg shadow-md hover:bg-primary-hover transition">
                    <div className="flex flex-col sm:flex-row w-full items-start">
                      <div className="flex-grow w-full sm:w-auto">
                        <Link href={`/books/${book.id}`} className="block">
                          <div className="flex items-center gap-2 mb-1">
                            <span className="text-xl font-medium text-foreground">
                              {book.highlights?.title?.[0] ? (
                                <span dangerouslySetInnerHTML={{ __html: book.highlights.title[0] }} />
                              ) : (
                                <Text>{book.title}</Text>
                              )}
                            </span>
                            {searchMode === 'fulltext' && book.score && (
                              <span className="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded-full">
                                匹配度: {book.score.toFixed(1)}
                              </span>
                            )}
                          </div>
                          <div className="text-sm text-muted-foreground mb-2">
                            {book.highlights?.author?.[0] ? (
                              <span dangerouslySetInnerHTML={{ __html: book.highlights.author[0] }} />
                            ) : (
                              <Text>{book.author}</Text>
                            )}
                          </div>
                        </Link>
                        {searchMode === 'fulltext' && book.highlights?.content && book.highlights.content.length > 0 && (
                          <div className="text-sm text-gray-600 mt-2 space-y-1">
                            {book.highlights.content.map((fragment, index) => {
                              // Use the original search term for highlighting, not the fragment
                              const highlightQuery = encodeURIComponent(searchTerm.trim());
                              // Clean HTML tags from fragment to get the text content
                              const cleanFragment = fragment.replace(/<[^>]+>/g, '');

                              // Find the search term in the fragment
                              const searchTermClean = searchTerm.trim();
                              const matchIndex = cleanFragment.indexOf(searchTermClean);

                              let shortContext = '';
                              if (matchIndex !== -1) {
                                // Find first symbol before the match
                                const symbolRegex = /[，。、；：！？""''（）【】《》\s]/;
                                let startIdx = matchIndex - 1;
                                while (startIdx >= 0 && !symbolRegex.test(cleanFragment[startIdx])) {
                                  startIdx--;
                                }
                                startIdx = Math.max(0, startIdx + 1); // Don't include the symbol itself

                                // Find first symbol after the match
                                let endIdx = matchIndex + searchTermClean.length;
                                while (endIdx < cleanFragment.length && !symbolRegex.test(cleanFragment[endIdx])) {
                                  endIdx++;
                                }

                                // Extract context and normalize it
                                const contextText = cleanFragment.substring(startIdx, endIdx);
                                shortContext = contextText.replace(/[，。、；：！？""''（）【】《》\s]/g, '_');
                              } else {
                                // Fallback: normalize the whole fragment
                                shortContext = cleanFragment.replace(/[，。、；：！？""''（）【】《》\s]/g, '_').split('_').filter(l => l.length > 0).slice(0, 3).join('_');
                              }

                              const fragmentContext = encodeURIComponent(shortContext);
                              return (
                                <Link
                                  key={index}
                                  href={`/books/${book.id}?highlight=${highlightQuery}&context=${fragmentContext}`}
                                  className="block leading-relaxed hover:bg-gray-100 px-2 py-1 rounded cursor-pointer transition"
                                >
                                  <span dangerouslySetInnerHTML={{ __html: '...' + fragment + '...' }} />
                                </Link>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    </div>
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

export default SearchPageClient;
