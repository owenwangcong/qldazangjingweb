"use client";

import React, { createContext, useState, useContext, useEffect } from 'react';

const DEFAULT_THEME: Theme = 'hupochangguang';

// Define and export the Theme type
export type Theme = 'lianchichanyun' | 'zhulinyoujing' | 'yueyingqinghui' | 'hupochangguang' | 'guchayese' | 'fagufanyin';

// Define the shape of the context value
interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
}

// Create the context without a default value
const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

// Optional: Provide a custom hook for easier usage
export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};

// Define the props type for ThemeProvider
interface ThemeProviderProps {
  children: React.ReactNode;
}

// Create a provider component
export const ThemeProvider: React.FC<ThemeProviderProps> = ({ children }) => {
  const storedTheme = typeof window !== 'undefined' ? localStorage.getItem('theme') : null;
  const validThemes: Theme[] = ['lianchichanyun', 'zhulinyoujing', 'yueyingqinghui', 'hupochangguang', 'guchayese', 'fagufanyin'];
  const initialTheme = validThemes.includes(storedTheme as Theme) ? (storedTheme as Theme) : DEFAULT_THEME;
  const [theme, setTheme] = useState<Theme>(initialTheme); // Default theme

  // Load the persisted theme from localStorage on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const actualStoredTheme = localStorage.getItem('theme');
      const themeToApply = actualStoredTheme || DEFAULT_THEME;
      setTheme(themeToApply as Theme);

      document.body.classList.remove('lianchichanyun', 'zhulinyoujing', 'yueyingqinghui', 'hupochangguang', 'guchayese', 'fagufanyin');
      document.body.classList.add(themeToApply);
    }
  }, []); // Empty dependency array - only run once on mount

  // Effect to update localStorage whenever theme changes
  useEffect(() => {
    if (typeof window !== 'undefined') {
      console.log('Setting theme in localStorage:', theme);
      localStorage.setItem('theme', theme);
    }
  }, [theme]);
  
  const handleSetTheme = (newTheme: Theme) => {
    console.log(`Theme changed to: ${newTheme}`);
    setTheme(newTheme);
    
    // Apply the theme to the document body
    document.body.classList.remove('lianchichanyun', 'zhulinyoujing', 'yueyingqinghui', 'hupochangguang', 'guchayese', 'fagufanyin');
    document.body.classList.add(newTheme);

    // Persist the theme to localStorage
    localStorage.setItem('theme', newTheme);
  };

  return (
    <ThemeContext.Provider value={{ theme, setTheme: handleSetTheme }}>
      {children}
    </ThemeContext.Provider>
  );
};

export default ThemeProvider;
