import React, { createContext, useState, useContext, useEffect } from 'react';

// Define and export the Theme type
export type Theme = 'lianchichanyun' | 'zhulinyoujing' | 'yueyingqinghui' | 'sangaijingtu' | 'guchayese' | 'fagufanyin';

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
  const [theme, setTheme] = useState<Theme>('sangaijingtu'); // Default theme

  // Load the persisted theme from localStorage on mount
  useEffect(() => {
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme && ['lianchichanyun', 'zhulinyoujing', 'yueyingqinghui', 'sangaijingtu', 'guchayese', 'fagufanyin'].includes(savedTheme)) {
      setTheme(savedTheme as Theme);
      document.body.classList.add(savedTheme);
    }
  }, []);

  const handleSetTheme = (newTheme: Theme) => {
    console.log(`Theme changed to: ${newTheme}`);
    setTheme(newTheme);
    
    // Apply the theme to the document body
    document.body.classList.remove('lianchichanyun', 'zhulinyoujing', 'yueyingqinghui', 'sangaijingtu', 'guchayese', 'fagufanyin');
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
