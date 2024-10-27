"use client";

import React, { createContext, useState, useContext, ReactNode, useEffect } from 'react';
import { Converter } from 'opencc-js';

interface LanguageContextProps {
  isSimplified: boolean;
  toggleLanguage: () => void;
  convertText: (text: string) => string;
}

const LanguageContext = createContext<LanguageContextProps>({
  isSimplified: true,
  toggleLanguage: () => {},
  convertText: (text: string) => text,
});

export const useLanguage = () => useContext(LanguageContext);

export const LanguageProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [isSimplified, setIsSimplified] = useState(true);

  // Load the persisted language preference from localStorage on mount
  useEffect(() => {
    const savedLanguage = typeof window !== 'undefined' ? localStorage.getItem('isSimplified') : null;
    if (savedLanguage !== null) {
      setIsSimplified(savedLanguage === 'true');
    }
  }, []);

  // Initialize converters
  const toTraditional = Converter({ from: 'cn', to: 'tw' });
  const toSimplified = Converter({ from: 'tw', to: 'cn' });

  // Update toggleLanguage to persist the new state to localStorage
  const toggleLanguage = () => {
    console.log("toggleLanguage");
    setIsSimplified((prev) => {
      const newValue = !prev;
      typeof window !== 'undefined' ? localStorage.setItem('isSimplified', newValue.toString()) : null;
      return newValue;
    });
  };

  const convertText = (text: string): string => {
    return isSimplified ? toSimplified(text) : toTraditional(text);
  };

  return (
    <LanguageContext.Provider value={{ isSimplified, toggleLanguage, convertText }}>
      {children}
    </LanguageContext.Provider>
  );
};
