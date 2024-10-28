"use client";

import React, { createContext, useState, useContext, ReactNode, useEffect } from 'react';
import { Converter } from 'opencc-js';

const DEFAULT_LANGUAGE = true;

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
  const [isSimplified, setIsSimplified] = useState<boolean>(DEFAULT_LANGUAGE);

  // Load the persisted language preference from localStorage on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const storedLanguage = localStorage.getItem('isSimplified');
      const storedLanguageToApply = storedLanguage === null ? DEFAULT_LANGUAGE : storedLanguage === 'true';
      setIsSimplified(storedLanguageToApply);
    }
  }, []);

  // Effect to update localStorage whenever language changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('isSimplified', isSimplified.toString());
    }
  }, [isSimplified]);

  // Initialize converters
  const toTraditional = Converter({ from: 'cn', to: 'tw' });
  const toSimplified = Converter({ from: 'tw', to: 'cn' });

  // Update toggleLanguage to persist the new state to localStorage
  const toggleLanguage = () => {
    setIsSimplified((prev) => !prev);
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
