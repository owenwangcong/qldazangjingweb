"use client";

import React, {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
} from "react";

// Define constants for default values
const DEFAULT_FONT = "--font-lxgw";
const DEFAULT_FONT_SIZE = "text-xl";
const DEFAULT_WIDTH = "max-w-4xl";
const DEFAULT_FONT_FAMILY = "inherit";

// Define the shape of the context data
interface FontContextProps {
  selectedFont: string; // The currently selected font
  setSelectedFont: (font: string) => void; // Function to update the selected font
  fontSize: string;
  setFontSize: (size: string) => void;
  selectedWidth: string;
  setSelectedWidth: (width: string) => void;
  fontFamily: string; // The current font family
  setFontFamily: (family: string) => void; // Function to update the font family
}

// Create the FontContext with default values
export const FontContext = createContext<FontContextProps>({
  selectedFont: "",
  setSelectedFont: () => {},
  fontSize: DEFAULT_FONT_SIZE,
  setFontSize: () => {},
  selectedWidth: DEFAULT_WIDTH,
  setSelectedWidth: () => {},
  fontFamily: DEFAULT_FONT_FAMILY,
  setFontFamily: () => {},
});

// FontProvider component to wrap around parts of the app that need access to the font context
export const FontProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  // Initialize selectedFont, selectedWidth, and fontFamily by attempting to load from localStorage first
  const storedFont =
    typeof window !== "undefined" ? localStorage.getItem("selectedFont") : null;
  const storedFontSize =
    typeof window !== "undefined" ? localStorage.getItem("fontSize") : null;
  const storedWidth =
    typeof window !== "undefined" ? localStorage.getItem("selectedWidth") : null;
  const storedFontFamily =
    typeof window !== "undefined" ? localStorage.getItem("fontFamily") : null;

  const [selectedFont, setSelectedFont] = useState<string>(
    storedFont || DEFAULT_FONT
  );
  const [fontSize, setFontSize] = useState<string>(
    storedFontSize || DEFAULT_FONT_SIZE
  );
  const [selectedWidth, setSelectedWidth] = useState<string>(
    storedWidth || DEFAULT_WIDTH
  );
  const [fontFamily, setFontFamily] = useState<string>(
    storedFontFamily || DEFAULT_FONT_FAMILY
  );

  // Effect to load the selected font, width, and fontFamily from localStorage on client side
  useEffect(() => {
    if (typeof window !== "undefined") {
      const actualStoredFont = localStorage.getItem("selectedFont");
      const actualStoredFontSize = localStorage.getItem("fontSize");
      const actualStoredWidth = localStorage.getItem("selectedWidth");
      const actualStoredFontFamily = localStorage.getItem("fontFamily");

      // Load the font from localStorage
      setSelectedFont(actualStoredFont || DEFAULT_FONT);

      // Load the font size from localStorage
      setFontSize(actualStoredFontSize || DEFAULT_FONT_SIZE);

      // Load the width from localStorage
      setSelectedWidth(actualStoredWidth || DEFAULT_WIDTH);

      // Load the fontFamily from localStorage
      setFontFamily(actualStoredFontFamily || DEFAULT_FONT_FAMILY);
    }
  }, []); // Empty dependency array - only run once on mount

  // Effect to update localStorage whenever selectedFont changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      console.log("Setting selectedFont in localStorage:", selectedFont);
      localStorage.setItem("selectedFont", selectedFont);
    }
  }, [selectedFont]);

  // Effect to update localStorage whenever fontSize changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      console.log("Setting fontSize in localStorage:", fontSize);
      localStorage.setItem("fontSize", fontSize);
    }
  }, [fontSize]);

  // Effect to update localStorage whenever selectedWidth changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      console.log("Setting selectedWidth in localStorage:", selectedWidth);
      localStorage.setItem("selectedWidth", selectedWidth);
    }
  }, [selectedWidth]);

  // Effect to update localStorage whenever fontFamily changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      console.log("Setting fontFamily in localStorage:", fontFamily);
      localStorage.setItem("fontFamily", fontFamily);
    }
  }, [fontFamily]);

  return (
    // Provide all context values to the context consumers
    <FontContext.Provider
      value={{
        selectedFont,
        setSelectedFont,
        fontSize,
        setFontSize,
        selectedWidth,
        setSelectedWidth,
        fontFamily,
        setFontFamily,
      }}
    >
      {children}
    </FontContext.Provider>
  );
};

// Custom hook to use the FontContext
export const useFont = (): FontContextProps => {
  const context = useContext(FontContext);
  if (!context) {
    throw new Error("useFont must be used within a FontProvider");
  }
  return context;
};
