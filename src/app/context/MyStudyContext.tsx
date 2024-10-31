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
interface MyStudyContextProps {
  favoriteBooks: string[];
  addFavoriteBook: (bookId: string) => void;
  removeFavoriteBook: (bookId: string) => void;
  browserHistory: string[];
  addToBrowserHistory: (bookId: string) => void;
  bookmarks: string[];
  addBookmark: (bookId: string) => void;
  removeBookmark: (bookId: string) => void;
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
});

// MyStudyProvider component to wrap around parts of the app that need access to the MyStudy context
export const MyStudyProvider: React.FC<{ children: ReactNode }> = ({ children }) => {

  const storedfavoriteBooks: string[] = typeof window !== "undefined" ? JSON.parse(localStorage.getItem("favoriteBooks") || "[]") : [];
  const storedHistory: string[] = typeof window !== "undefined" ? JSON.parse(localStorage.getItem("browserHistory") || "[]") : [];
  const storedBookmarks: string[] = typeof window !== "undefined" ? JSON.parse(localStorage.getItem("bookmarks") || "[]") : [];

  const [favoriteBooks, setFavoriteBooks] = useState<string[]>(storedfavoriteBooks || []);
  const [browserHistory, setBrowserHistory] = useState<string[]>(storedHistory || []);
  const [bookmarks, setBookmarks] = useState<string[]>(storedBookmarks || []);

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

  // Add a book to favorites
  const addFavoriteBook = (bookId: string) => {
    console.log('addFavoriteBook in context', bookId);
    setFavoriteBooks((prev) => {
      if (!prev.includes(bookId)) {
        return [...prev, bookId];
      }
      return prev;
    });
  };

  // Remove a book from favorites
  const removeFavoriteBook = (bookId: string) => {
    setFavoriteBooks((prev) => prev.filter((id) => id !== bookId));
  };

  // Add a book to browser history
  const addToBrowserHistory = (bookId: string) => {
    setBrowserHistory((prev) => {
      const updatedHistory = [bookId, ...prev.filter((id) => id !== bookId)];
      return updatedHistory.slice(0, 50); // Limit history to last 50 items
    });
  };

  // Add a bookmark
  const addBookmark = (bookId: string) => {
    setBookmarks((prev) => {
      if (!prev.includes(bookId)) {
        return [...prev, bookId];
      }
      return prev;
    });
  };

  // Remove a bookmark
  const removeBookmark = (bookId: string) => {
    setBookmarks((prev) => prev.filter((id) => id !== bookId));
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