"use client";

import React, { createContext, useContext, useState, ReactNode, useEffect } from 'react';

// Define constants for default values
const DEFAULT_FONT = '--font-lxgw';
const DEFAULT_FONT_SIZE = 'text-xl';
const DEFAULT_WIDTH = 'max-w-4xl';

// Define the shape of the context data
interface FontContextProps {
  selectedFont: string; // The currently selected font
  setSelectedFont: (font: string) => void; // Function to update the selected font
  fontSize: string;
  setFontSize: (size: string) => void;
  selectedWidth: string;
  setSelectedWidth: (width: string) => void;
}

// Create the FontContext with default values
export const FontContext = createContext<FontContextProps>({
  selectedFont: '',
  setSelectedFont: () => {},
  fontSize: DEFAULT_FONT_SIZE,
  setFontSize: () => {},
  selectedWidth: DEFAULT_WIDTH,
  setSelectedWidth: () => {},
});

// FontProvider component to wrap around parts of the app that need access to the font context
export const FontProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  // Initialize selectedFont and selectedWidth by attempting to load from localStorage first
  const storedFont = typeof window !== 'undefined' ? localStorage.getItem('selectedFont') : null;
  const storedFontSize = typeof window !== 'undefined' ? localStorage.getItem('fontSize') : null;
  const storedWidth = typeof window !== 'undefined' ? localStorage.getItem('selectedWidth') : null;

  const [selectedFont, setSelectedFont] = useState<string>(storedFont || DEFAULT_FONT);
  const [fontSize, setFontSize] = useState<string>(storedFontSize || DEFAULT_FONT_SIZE);
  const [selectedWidth, setSelectedWidth] = useState<string>(storedWidth || DEFAULT_WIDTH);

  // Effect to load the selected font and width from localStorage on client side
  useEffect(() => {
    if (typeof window !== 'undefined') {
      // Load the font from localStorage
      setSelectedFont(storedFont || DEFAULT_FONT);

      // Load the font size from localStorage
      setFontSize(storedFontSize || DEFAULT_FONT_SIZE);

      // Load the width from localStorage
      setSelectedWidth(storedWidth || DEFAULT_WIDTH);
    }
  }, []);

  // Effect to update localStorage whenever selectedFont changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      console.log('Setting selectedFont in localStorage:', selectedFont);
      localStorage.setItem('selectedFont', selectedFont);
    }
  }, [selectedFont]);

  // Effect to update localStorage whenever fontSize changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      console.log('Setting fontSize in localStorage:', fontSize);
      localStorage.setItem('fontSize', fontSize);
    }
  }, [fontSize]);

  // Effect to update localStorage whenever selectedWidth changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      console.log('Setting selectedWidth in localStorage:', selectedWidth);
      localStorage.setItem('selectedWidth', selectedWidth);
    }
  }, [selectedWidth]);

  return (
    // Provide the selectedFont, setSelectedFont, fontSize, setFontSize, selectedWidth, and setSelectedWidth to the context consumers
    <FontContext.Provider value={{ selectedFont, setSelectedFont, fontSize, setFontSize, selectedWidth, setSelectedWidth }}>
      {children}
    </FontContext.Provider>
  );
};

// Custom hook to use the FontContext
export const useFont = (): FontContextProps => {
  const context = useContext(FontContext);
  if (!context) {
    throw new Error('useFont must be used within a FontProvider');
  }
  return context;
};
