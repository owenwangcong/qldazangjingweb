"use client";

import React, {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
} from "react";

// Define the shape of a Book
interface Book {
  id: string;
  name: string;
  href: string;
  bu: string;
  title: string;
  author: string;
  volume: string;
}

// Define the shape of a context data
export interface FavoriteBook {
  bookId: string;
  timestamp: number;
}

export interface BrowserHistoryItem {
  bookId: string;
  timestamp: number;
}

export interface Bookmark {
  compositeKey: string;
  bookId: string;
  partId: string;
  timestamp: number;
  content: string;
}

interface MyStudyContextProps {
  favoriteBooks: FavoriteBook[];
  addFavoriteBook: (bookId: string) => void;
  removeFavoriteBook: (bookId: string) => void;
  browserHistory: BrowserHistoryItem[];
  addToBrowserHistory: (bookId: string) => void;
  bookmarks: Bookmark[];
  addBookmark: (bookId: string, partId: string, content: string) => void;
  removeBookmark: (bookId: string, partId: string) => void;
  currentPartId: string | null;
  setCurrentPartId: (id: string | null) => void;
}

// Create the MyStudyContext with default values
export const MyStudyContext = createContext<MyStudyContextProps>({
  favoriteBooks: [],
  addFavoriteBook: () => {},
  removeFavoriteBook: () => {},
  browserHistory: [],
  addToBrowserHistory: () => {},
  bookmarks: [],
  addBookmark: () => {},
  removeBookmark: () => {},
  currentPartId: null,
  setCurrentPartId: () => {},
});

// MyStudyProvider component to wrap around parts of the app that need access to the MyStudy context
export const MyStudyProvider: React.FC<{ children: ReactNode }> = ({ children }) => {

  const storedFavoriteBooks: FavoriteBook[] = typeof window !== "undefined" ? JSON.parse(localStorage.getItem("favoriteBooks") || "[]") : [];
  const storedHistory: BrowserHistoryItem[] = typeof window !== "undefined" ? JSON.parse(localStorage.getItem("browserHistory") || "[]") : [];
  const storedBookmarks: Bookmark[] = typeof window !== "undefined" ? JSON.parse(localStorage.getItem("bookmarks") || "[]") : [];

  const [favoriteBooks, setFavoriteBooks] = useState<FavoriteBook[]>(storedFavoriteBooks);
  const [browserHistory, setBrowserHistory] = useState<BrowserHistoryItem[]>(storedHistory);
  const [bookmarks, setBookmarks] = useState<Bookmark[]>(storedBookmarks);
  const [currentPartId, setCurrentPartId] = useState<string | null>(null);

  // Load from localStorage on mount
  useEffect(() => {
    if (typeof window !== "undefined") {
      const storedFavorites = localStorage.getItem("favoriteBooks");
      const storedHistory = localStorage.getItem("browserHistory");
      const storedBookmarks = localStorage.getItem("bookmarks");

      if (storedFavorites) {
        setFavoriteBooks(JSON.parse(storedFavorites));
      }
      if (storedHistory) {
        setBrowserHistory(JSON.parse(storedHistory));
      }
      if (storedBookmarks) {
        setBookmarks(JSON.parse(storedBookmarks));
      }
    }
  }, []);

  // Save to localStorage whenever favoriteBooks changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      localStorage.setItem("favoriteBooks", JSON.stringify(favoriteBooks));
    }
  }, [favoriteBooks]);

  // Save to localStorage whenever browserHistory changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      localStorage.setItem("browserHistory", JSON.stringify(browserHistory));
    }
  }, [browserHistory]);

  // Save to localStorage whenever bookmarks changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      localStorage.setItem("bookmarks", JSON.stringify(bookmarks));
    }
  }, [bookmarks]);

  // Add a book to favorites with timestamp
  const addFavoriteBook = (bookId: string) => {
    const timestamp = Date.now();
    setFavoriteBooks((prev) => {
      if (!prev.some(book => book.bookId === bookId)) {
        return [...prev, { bookId, timestamp }];
      }
      return prev;
    });
  };

  // Remove a book from favorites
  const removeFavoriteBook = (bookId: string) => {
    setFavoriteBooks((prev) => prev.filter((book) => book.bookId !== bookId));
  };

  // Add a book to browser history with timestamp
  const addToBrowserHistory = (bookId: string) => {
    const timestamp = Date.now();
    setBrowserHistory((prev) => {
      const updatedHistory = [{ bookId, timestamp }, ...prev.filter((item) => item.bookId !== bookId)];
      return updatedHistory.slice(0, 50); // Limit history to last 50 items
    });
  };

  // Add a bookmark with a composite key (bookId and partId)
  const addBookmark = (bookId: string, partId: string, content: string) => {
    const timestamp = Date.now();
    setBookmarks((prev) => {
      const compositeKey = `${bookId}-${partId}`;
      if (!prev.some(bm => `${bm.compositeKey}` === compositeKey)) {
        return [...prev, { compositeKey, bookId, partId, timestamp, content }];
      }
      return prev;
    });
  };

  // Remove a bookmark
  const removeBookmark = (bookId: string, partId: string) => {
    const compositeKey = `${bookId}-${partId}`;
    setBookmarks((prev) => prev.filter((bm) => !(bm.compositeKey === compositeKey)));
  };

  return (
    <MyStudyContext.Provider
      value={{
        favoriteBooks,
        addFavoriteBook,
        removeFavoriteBook,
        browserHistory,
        addToBrowserHistory,
        bookmarks,
        addBookmark,
        removeBookmark,
        currentPartId,
        setCurrentPartId,
      }}
    >
      {children}
    </MyStudyContext.Provider>
  );
};

// Custom hook to use the MyStudyContext
export const useMyStudy = (): MyStudyContextProps => {
  const context = useContext(MyStudyContext);
  if (!context) {
    throw new Error("useMyStudy must be used within a MyStudyProvider");
  }
  return context;
}; 