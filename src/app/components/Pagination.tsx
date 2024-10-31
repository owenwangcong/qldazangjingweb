"use client";

import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import classNames from 'classnames';

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

const Pagination: React.FC<PaginationProps> = ({ currentPage, totalPages, onPageChange }) => {
  const handlePrevious = () => {
    onPageChange(Math.max(currentPage - 1, 1));
  };

  const handleNext = () => {
    onPageChange(Math.min(currentPage + 1, totalPages));
  };

  const handlePageSelect = (page: number) => {
    onPageChange(page);
  };

  const pages: (number | JSX.Element)[] = [];
  const delta = 1;

  const startPage = Math.max(2, currentPage - delta);
  const endPage = Math.min(totalPages - 1, currentPage + delta);

  for (let i = startPage; i <= endPage; i++) {
    pages.push(i);
  }

  if (totalPages > 1) {
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

    if (endPage < totalPages - 1) {
      pages.push(
        <span key="end-ellipsis" className="px-3 py-1 text-gray-500" aria-hidden="true">
          ...
        </span>
      );
      pages.push(
        <button
          key={totalPages}
          onClick={() => handlePageSelect(totalPages)}
          className={classNames(
            'px-3 py-1 rounded-md',
            currentPage === totalPages
              ? 'bg-primary text-primary-foreground'
              : 'bg-muted text-muted-foreground hover:bg-muted-foreground-hover'
          )}
          aria-label={`第 ${totalPages} 页`}
        >
          {totalPages}
        </button>
      );
    } else {
      for (let i = endPage + 1; i <= totalPages; i++) {
        pages.push(i);
      }
    }
  }

  return (
    <div className="w-full flex justify-center items-center mt-4 space-x-4">
      {totalPages > 1 && (
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
      )}
      <div className="flex justify-center space-x-2">
        {pages.map((page, index) => {
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
        })}
      </div>
      {totalPages > 1 && (
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
      )}
    </div>
  );
};

export default Pagination; 