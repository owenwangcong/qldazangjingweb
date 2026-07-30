"use client";

import React, {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
} from "react";

// 字重三档(claudedocs/font-weight-quotes-plan.md FQ1):8 款字体全是单字重
// Regular,真字重不可得,以描边合成粗化;档位与 Flutter 端一致。
export type FontWeightGear = "normal" | "medium" | "bold";

// 档位 → -webkit-text-stroke-width(em 随字号缩放;颜色默认 currentColor)。
export const FONT_WEIGHT_STROKE: Record<FontWeightGear, string> = {
  normal: "0px",
  medium: "0.02em",
  bold: "0.04em",
};

// Define constants for default values
const DEFAULT_FONT = "--font-lxgw";
const DEFAULT_FONT_SIZE = "text-xl";
const DEFAULT_WIDTH = "max-w-4xl";
const DEFAULT_FONT_FAMILY = "inherit";
const DEFAULT_LINE_HEIGHT = 1.75;
const DEFAULT_PARAGRAPH_SPACING = "0.75rem";
const DEFAULT_LETTER_SPACING = "normal";
const DEFAULT_FONT_WEIGHT_GEAR: FontWeightGear = "normal";

const asFontWeightGear = (value: string | null): FontWeightGear =>
  value === "medium" || value === "bold" ? value : DEFAULT_FONT_WEIGHT_GEAR;

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
  lineHeight: number; // Line height
  setLineHeight: (height: number) => void; // Function to update line height
  paragraphSpacing: string; // Paragraph spacing
  setParagraphSpacing: (spacing: string) => void; // Function to update paragraph spacing
  letterSpacing: string; // Letter spacing
  setLetterSpacing: (spacing: string) => void; // Function to update letter spacing
  fontWeightGear: FontWeightGear; // 字重档(仅经文正文,横竖排共用)
  setFontWeightGear: (gear: FontWeightGear) => void;
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
  lineHeight: DEFAULT_LINE_HEIGHT,
  setLineHeight: () => {},
  paragraphSpacing: DEFAULT_PARAGRAPH_SPACING,
  setParagraphSpacing: () => {},
  letterSpacing: DEFAULT_LETTER_SPACING,
  setLetterSpacing: () => {},
  fontWeightGear: DEFAULT_FONT_WEIGHT_GEAR,
  setFontWeightGear: () => {},
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
  const storedLineHeight =
    typeof window !== "undefined" ? localStorage.getItem("lineHeight") : null;
  const storedParagraphSpacing =
    typeof window !== "undefined" ? localStorage.getItem("paragraphSpacing") : null;
  const storedLetterSpacing =
    typeof window !== "undefined" ? localStorage.getItem("letterSpacing") : null;
  const storedFontWeightGear =
    typeof window !== "undefined" ? localStorage.getItem("fontWeightGear") : null;

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
  const [lineHeight, setLineHeight] = useState<number>(
    storedLineHeight ? parseFloat(storedLineHeight) : DEFAULT_LINE_HEIGHT
  );
  const [paragraphSpacing, setParagraphSpacing] = useState<string>(
    storedParagraphSpacing || DEFAULT_PARAGRAPH_SPACING
  );
  const [letterSpacing, setLetterSpacing] = useState<string>(
    storedLetterSpacing || DEFAULT_LETTER_SPACING
  );
  const [fontWeightGear, setFontWeightGear] = useState<FontWeightGear>(
    asFontWeightGear(storedFontWeightGear)
  );

  // Effect to load the selected font, width, and fontFamily from localStorage on client side
  useEffect(() => {
    if (typeof window !== "undefined") {
      const actualStoredFont = localStorage.getItem("selectedFont");
      const actualStoredFontSize = localStorage.getItem("fontSize");
      const actualStoredWidth = localStorage.getItem("selectedWidth");
      const actualStoredFontFamily = localStorage.getItem("fontFamily");
      const actualStoredLineHeight = localStorage.getItem("lineHeight");
      const actualStoredParagraphSpacing = localStorage.getItem("paragraphSpacing");
      const actualStoredLetterSpacing = localStorage.getItem("letterSpacing");

      // Load the font from localStorage
      setSelectedFont(actualStoredFont || DEFAULT_FONT);

      // Load the font size from localStorage
      setFontSize(actualStoredFontSize || DEFAULT_FONT_SIZE);

      // Load the width from localStorage
      setSelectedWidth(actualStoredWidth || DEFAULT_WIDTH);

      // Load the fontFamily from localStorage
      setFontFamily(actualStoredFontFamily || DEFAULT_FONT_FAMILY);

      // Load the line height from localStorage
      setLineHeight(actualStoredLineHeight ? parseFloat(actualStoredLineHeight) : DEFAULT_LINE_HEIGHT);

      // Load the paragraph spacing from localStorage
      setParagraphSpacing(actualStoredParagraphSpacing || DEFAULT_PARAGRAPH_SPACING);

      // Load the letter spacing from localStorage
      setLetterSpacing(actualStoredLetterSpacing || DEFAULT_LETTER_SPACING);

      // Load the font weight gear from localStorage
      setFontWeightGear(asFontWeightGear(localStorage.getItem("fontWeightGear")));
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

  // Effect to update localStorage whenever lineHeight changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      console.log("Setting lineHeight in localStorage:", lineHeight);
      localStorage.setItem("lineHeight", lineHeight.toString());
    }
  }, [lineHeight]);

  // Effect to update localStorage whenever paragraphSpacing changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      console.log("Setting paragraphSpacing in localStorage:", paragraphSpacing);
      localStorage.setItem("paragraphSpacing", paragraphSpacing);
    }
  }, [paragraphSpacing]);

  // Effect to update localStorage whenever letterSpacing changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      console.log("Setting letterSpacing in localStorage:", letterSpacing);
      localStorage.setItem("letterSpacing", letterSpacing);
    }
  }, [letterSpacing]);

  // Effect to update localStorage whenever fontWeightGear changes
  useEffect(() => {
    if (typeof window !== "undefined") {
      localStorage.setItem("fontWeightGear", fontWeightGear);
    }
  }, [fontWeightGear]);

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
        lineHeight,
        setLineHeight,
        paragraphSpacing,
        setParagraphSpacing,
        letterSpacing,
        setLetterSpacing,
        fontWeightGear,
        setFontWeightGear,
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
