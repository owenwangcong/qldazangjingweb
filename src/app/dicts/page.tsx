"use client";

import React, { useState, useEffect } from 'react';
import { Search as SearchIcon } from 'lucide-react';
import classNames from 'classnames';
import Text from '@/app/components/Text';
import Header from '@/app/components/Header';

const DictsPage: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [results, setResults] = useState<any[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // Handle search input changes
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const term = e.target.value;
    setSearchTerm(term);
  };

  // Handle search button click
  const handleSearch = () => {
    const trimmedTerm = searchTerm.trim();
    if (trimmedTerm === '') {
      setResults([]);
      return;
    }
    fetchResults(trimmedTerm);
  };

  // Fetch results from dictionary API
  const fetchResults = async (term: string) => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch('/api/todict/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ key: term }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Network response was not ok');
      }

      const data = await response.json();
      setResults(data.results || []);
    } catch (err: any) {
      setError(err.message || 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-10 gap-8 sm:p-10">
        <h1 className="text-3xl font-bold"><Text>搜索辞典</Text></h1>
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
              placeholder="输入要查询的词"
              aria-label="搜索字典"
            />
            <button
              onClick={handleSearch}
              className="px-4 py-2 w-full sm:w-32 bg-primary text-white rounded-md hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary"
              aria-label="触发搜索"
            >
              <Text>查询</Text>
            </button>
          </div>
        </div>
        {loading && <p className="mt-4 text-gray-600"><Text>查询辞典中...</Text></p>}
        {error && <p className="mt-4 text-red-500"><Text>错误</Text>: {error}</p>}
        {!loading && !error && results.length > 0 && (
          <div className="w-full max-w-4xl">
            <ul className="space-y-4">
              {results.map(({ id, key, dict, value }) => (
                <li key={id} className="p-4 border border-border rounded-lg shadow-md font-sans">
                  <div className="flex justify-between items-center">
                    <span className="text-xl font-medium text-foreground bg-primary-hover flex-grow text-center mb-2">
                      <Text>{dict}</Text>
                    </span>
                  </div>
                  <p className="text-md text-muted-foreground flex-none text-left">
                    <Text>{value}</Text>
                  </p>
                </li>
              ))}
            </ul>
          </div>
        )}
        {!loading && !error && !results && searchTerm.trim() !== '' && (
          <p className="mt-4 text-gray-600">
            <Text>未找到匹配的结果</Text>
          </p>
        )}
      </div>
    </div>
  );
};

export default DictsPage;