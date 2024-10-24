"use client";

import React, { createContext, useContext, useState, ReactNode, useEffect } from 'react';

// Define a constant for the default font
const DEFAULT_FONT = '--font-lxgw';

// Define the shape of the context data
interface FontContextProps {
  selectedFont: string; // The currently selected font
  setSelectedFont: (font: string) => void; // Function to update the selected font
}

// Create the FontContext with default values
export const FontContext = createContext<FontContextProps>({
  selectedFont: DEFAULT_FONT,
  setSelectedFont: () => {},
});

// FontProvider component to wrap around parts of the app that need access to the font context
export const FontProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  // Initialize selectedFont by attempting to load from localStorage first
  const storedFont = typeof window !== 'undefined' ? localStorage.getItem('selectedFont') : null;
  const [selectedFont, setSelectedFont] = useState<string>(storedFont || DEFAULT_FONT);

  // Effect to load the selected font from localStorage on client side
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const storedFont = localStorage.getItem('selectedFont');
      if (storedFont) {
        console.log('Loaded font from localStorage:', storedFont);
        setSelectedFont(storedFont);
      } else {
        console.log('No font found in localStorage, using default:', DEFAULT_FONT);
      }
    }
  }, []);

  // Effect to update localStorage whenever selectedFont changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      console.log('Setting selectedFont in localStorage:', selectedFont);
      localStorage.setItem('selectedFont', selectedFont);
    }
  }, [selectedFont]);

  return (
    // Provide the selectedFont and setSelectedFont to the context consumers
    <FontContext.Provider value={{ selectedFont, setSelectedFont }}>
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
