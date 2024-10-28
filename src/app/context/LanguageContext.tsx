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
  const storedLanguage = typeof window !== 'undefined' ? localStorage.getItem('isSimplified') : null;

  const [isSimplified, setIsSimplified] = useState<boolean>(storedLanguage === 'true' || DEFAULT_LANGUAGE);

  // Load the persisted language preference from localStorage on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      setIsSimplified(storedLanguage === 'true');    
    }
  }, []);

  // Effect to update localStorage whenever language changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      console.log('Setting language in localStorage:', isSimplified);
      localStorage.setItem('isSimplified', isSimplified.toString());
    }
  }, [isSimplified]);

  // Initialize converters
  const toTraditional = Converter({ from: 'cn', to: 'tw' });
  const toSimplified = Converter({ from: 'tw', to: 'cn' });

  // Update toggleLanguage to persist the new state to localStorage
  const toggleLanguage = () => {
    console.log("toggleLanguage");
    setIsSimplified((prev) => {
      const newValue = !prev;
      localStorage.setItem('isSimplified', newValue.toString());
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
