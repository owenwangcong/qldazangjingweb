import React, { createContext, useState, ReactNode } from 'react';

interface Book {
  id: string;
  meta: {
    title: string;
    Arthur: string;
  };
  juans: any[];
}

interface BookContextType {
  book: Book | null;
  setBook: (book: Book) => void;
}

export const BookContext = createContext<BookContextType>({
  book: null,
  setBook: () => {},
});

export const BookProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [book, setBook] = useState<Book | null>(null);

  return (
    <BookContext.Provider value={{ book, setBook }}>
      {children}
    </BookContext.Provider>
  );
}; 