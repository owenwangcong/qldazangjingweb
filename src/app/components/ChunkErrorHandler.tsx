"use client";

import { useEffect } from 'react';

export default function ChunkErrorHandler() {
  useEffect(() => {
    // Handle chunk load errors
    const handleError = (event: ErrorEvent) => {
      const isChunkLoadError =
        event.message?.includes('ChunkLoadError') ||
        event.message?.includes('Loading chunk') ||
        event.message?.includes('Failed to fetch dynamically imported module');

      if (isChunkLoadError) {
        console.log('Chunk load error detected, reloading page...');
        // Reload the page to get the latest chunks
        window.location.reload();
      }
    };

    // Handle unhandled promise rejections (for dynamic imports)
    const handleRejection = (event: PromiseRejectionEvent) => {
      const error = event.reason;
      const isChunkLoadError =
        error?.name === 'ChunkLoadError' ||
        error?.message?.includes('Loading chunk') ||
        error?.message?.includes('Failed to fetch dynamically imported module');

      if (isChunkLoadError) {
        console.log('Chunk load error detected, reloading page...');
        event.preventDefault();
        window.location.reload();
      }
    };

    window.addEventListener('error', handleError);
    window.addEventListener('unhandledrejection', handleRejection);

    return () => {
      window.removeEventListener('error', handleError);
      window.removeEventListener('unhandledrejection', handleRejection);
    };
  }, []);

  return null;
}
