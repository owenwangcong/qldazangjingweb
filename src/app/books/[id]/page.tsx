"use client";

import React, { useState, useEffect, useRef, useContext } from 'react';
import { useParams } from 'next/navigation';
import Header from '@/app/components/Header';
import * as DropdownMenu from "@radix-ui/react-dropdown-menu"
import { FontProvider, FontContext } from '@/app/context/FontContext';
import FontWrapper from '@/app/components/FontWrapper';
import Text from '@/app/components/Text';

const BookDetailPage: React.FC = () => {
  const { id } = useParams();
  const [book, setBook] = useState<any>(null);
  const [selectedText, setSelectedText] = useState<string>('');
  const [contextMenuPosition, setContextMenuPosition] = useState<{ x: number, y: number } | null>(null);
  const contextMenuRef = useRef<HTMLDivElement>(null);
  const { selectedFont, setSelectedFont } = useContext(FontContext);

  // This code block handles the text selection and context menu functionality for the book detail page.
  // It sets the selected text and context menu position based on user interactions.
  const [menuLevel, setMenuLevel] = useState('main');
  const [selectedItem, setSelectedItem] = useState<string | null>(null);
  const [contentData, setContentData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const [fontFamily, setFontFamily] = useState<string>('inherit');

  // Fetch the book data based on the id
  const fetchBookData = async (id: string) => {
    try {
      const response = await import(`@/app/data/books/${id}.json`);
      return response.default;
    } catch (error) {
      console.error("Error fetching book data:", error);
      return null;
    }
  };

  const fetchFontData = async (selectedFontFamilyName: string, bookId: string) => {
    try {
      // Dynamically import the font file based on the fontId and bookId.
      const fontMapping: { [key: string]: string } = {
        '--font-aakai': 'aaKaiTi',
        '--font-aakaiSong': 'aaKaiSong',
        '--font-lxgw': 'lxgw',
        '--font-hyfs': 'hyFangSong',
        '--font-qnlb': 'qnBianLi',
        '--font-rzykt': 'rzyKaiTi',
        '--font-twzk': 'twZhengKai',
        '--font-wqwh': 'wqwMiHei',
      };

      const selectedFontName = fontMapping[selectedFontFamilyName] || 'DefaultFont';
      const response = await import(`@/app/fonts/book_fonts/${selectedFontName}_${bookId}.woff`);
      console.log('Font URL:', response.default);
      return response.default;
    } catch (error) {
      console.error("Error fetching font data:", error);
      return null;
    }
  };

  const handleTextSelection = () => {
    const selection = window.getSelection();
    if (selection && selection.toString().trim()) {
      const selected = selection.toString();
      console.log('Selected text:', selected); // Debug: Log selected text
      setSelectedText(selected);
    } else {
      console.log('No text selected'); // Debug: Log when no text is selected
      setSelectedText("");
      setContextMenuPosition(null);
    }
  };

  const handleContextMenu = (event: React.MouseEvent) => {
    const selection = window.getSelection();
    if (selection && selection.toString().trim()) {
      event.preventDefault();
      console.log('Context menu triggered at:', event.clientX, event.clientY); // Debug: Log context menu position
      setContextMenuPosition({
        x: event.clientX,
        y: event.clientY,
      });
    } else {
      setContextMenuPosition(null);
    }
  };

  const handleMenuClose = () => {
    console.log('Context menu closed'); // Debug: Log when context menu is closed
    setContextMenuPosition(null);

    // Reset the menu level, selected item, and content data
    setMenuLevel('main');
    setSelectedItem(null);
    setContentData(null);

  };

  // Handle dropdown menu item clicks
  const handleCopy = () => {
    if (selectedText) {
      navigator.clipboard.writeText(selectedText);
      console.log('Text copied:', selectedText);
    }
    handleMenuClose();
  };

  const handleSearch = () => {
    if (selectedText) {
      console.log('Search for:', selectedText);
      const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(selectedText)}`;
      window.open(searchUrl, '_blank');
    }
    handleMenuClose();
  };

  const handleDictionary = () => {
    setSelectedItem("lookup dictionary")
    if (selectedText) {
      console.log('Look up dictionary for:', selectedText);
      // Implement dictionary lookup logic here
    }
    //handleMenuClose();
  };

  const handleFavorite = () => {
    if (selectedText) {
      console.log('Marked as favorite:', selectedText);
      // Implement favorite logic here, e.g., save to local storage or a database
    }
    handleMenuClose();
  };

  // Define the handleBaiHuaWen function
  const handleToModernChinese = () => {
    setSelectedItem("to modern chinese")
    if (selectedText) {
      console.log('Convert to Bai Hua Wen:', selectedText);
      // Implement Bai Hua Wen conversion logic here
    }
    //handleMenuClose();
  };

  // Define the handleShiYi function
  const handleExplain = () => {
    setSelectedItem("explain")
    if (selectedText) {
      console.log('Interpretation for:', selectedText);
      // Implement interpretation logic here
    }
    //handleMenuClose();
  };

  // This useEffect hook fetches the book data when the component mounts or when the id changes.
  useEffect(() => {
    if (id) {
      fetchBookData(id as string).then(setBook);
    }
  }, [id]);

  // This useEffect hook adds an event listener to handle clicks outside the context menu and closes the menu when a click outside is detected.
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      // Check if the context menu reference is defined and if the clicked target is outside the context menu
      if (contextMenuRef.current && !contextMenuRef.current.contains(event.target as Node)) {
        handleMenuClose();
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  useEffect(() => {
    if (selectedItem) {
      setLoading(true);
      setError(null);
  
      // Replace this URL with your API endpoint
      //const apiUrl = `https://api.example.com/data/${selectedItem}`;
      const apiUrl = `https://httpbin.org/get?${selectedItem}`;
  
      fetch(apiUrl)
        .then((response) => {
          if (!response.ok) {
            throw new Error('Network response was not ok');
          }
          return response.json();
        })
        .then((data) => {
          setContentData(data);
          setLoading(false);
          setMenuLevel('content'); // Move to content view
        })
        .catch((error) => {
          setError(error.message);
          setLoading(false);
        });
    }
  }, [selectedItem]);

  // Fetch the font data when the selected font or id changes
  useEffect(() => {
    if (selectedFont && id) {
      fetchFontData(selectedFont as string, id as string).then((fontUrl) => {
        if (fontUrl) {
          const fontName = `custom-font-${selectedFont}-${id}`;
          const newStyle = document.createElement('style');
          newStyle.innerHTML = `
            @font-face {
              font-family: '${fontName}';
              src: url('${fontUrl}') format('woff');
              font-weight: normal;
              font-style: normal;
            }
          `;
          document.head.appendChild(newStyle);
          setFontFamily(fontName);
        }
      });
    }
  }, [selectedFont, id]);

  if (!book) {
    return (
      <>
        <Header />
        <div className="flex justify-center items-center h-screen">
          <h1 className="text-3xl font-bold"><Text>Book not found</Text></h1>
        </div>
      </>
    );
  }

  return (
    <>
      <Header />
      <div
        className="flex flex-col items-center min-h-screen p-8 pb-10 gap-10 sm:p-10"
        onMouseUp={handleTextSelection}
        onContextMenu={handleContextMenu}
      >
        <h1 className="text-3xl font-bold"><Text>{book.meta.title}</Text></h1>
        <h2 className="text-xl"><Text>{book.meta.Arthur}</Text></h2>
        <div className="w-full max-w-4xl" style={{ fontFamily }}>
          {book.juans.map((juan: any, juanIndex: number) => (
            <div key={juan.id || `juan-${juanIndex}`} className="mb-8">
              <h3 className="text-2xl font-semibold"><Text>{juan.name}</Text></h3>
              {juan.chapters.map((chapter: any, chapterIndex: number) => (
                <div key={chapter.id || `chapter-${juanIndex}-${chapterIndex}`} className="mt-4">
                  <h4 className="text-xl font-medium"><Text>{chapter.name}</Text></h4>
                  {chapter.paragraphs.map((paragraph: string, paragraphIndex: number) => (
                    <p key={`paragraph-${juanIndex}-${chapterIndex}-${paragraphIndex}`} className="text-lg mt-2">
                      {paragraph.split('”').map((part, index, array) => (
                        <React.Fragment key={index}>
                          <Text>{part}</Text>
                          {index < array.length - 1 && '”'}
                          {index < array.length - 1 && <br />}
                        </React.Fragment>
                      ))}
                    </p>
                  ))}
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>

      {/* This div handles the context menu for text selection */}
      <div onContextMenu={handleContextMenu} className="relative" ref={contextMenuRef}>
        <DropdownMenu.Root open={!!contextMenuPosition}>
          <DropdownMenu.Trigger asChild>
            <button className="hidden" />
          </DropdownMenu.Trigger>
          <DropdownMenu.Content
            sideOffset={5}
            style={{
              position: 'absolute',
              top: contextMenuPosition?.y,
              left: contextMenuPosition?.x,
            }}
            className="bg-white shadow-lg rounded-md p-2"
            onMouseLeave={handleMenuClose} // Close menu when mouse leaves
          >

          {menuLevel === 'main' && (
            <>
              <DropdownMenu.Item
                className="flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent focus:text-accent-foreground hover:bg-gray-200 whitespace-nowrap"
                onSelect={handleCopy}
              >
                <Text>复制</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-gray-200" />
              <DropdownMenu.Item
                className="flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent focus:text-accent-foreground hover:bg-gray-200 whitespace-nowrap"
                onSelect={handleSearch}
              >
                <Text>搜索</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-gray-200" />
              <DropdownMenu.Item
                className="flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent focus:text-accent-foreground hover:bg-gray-200 whitespace-nowrap"
                onSelect={handleDictionary}
              >
                <Text>字典</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-gray-200" />
              <DropdownMenu.Item
                className="flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent focus:text-accent-foreground hover:bg-gray-200 whitespace-nowrap"
                onSelect={handleFavorite}
              >
                <Text>收藏</Text> 
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-gray-200" />
              <DropdownMenu.Item
                className="flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent focus:text-accent-foreground hover:bg-gray-200 whitespace-nowrap"
                onSelect={handleToModernChinese}
              >
                <Text>今译</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-gray-200" />
              <DropdownMenu.Item
                className="flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent focus:text-accent-foreground hover:bg-gray-200 whitespace-nowrap"
                onSelect={handleExplain}
              >
                <Text>释义</Text>
              </DropdownMenu.Item>
            </>
          )}
          {menuLevel === 'content' && (
            <>
              <DropdownMenu.Item
                className="DropdownMenuItem"
                onSelect={() => {
                  setMenuLevel('main');
                  setSelectedItem(null);
                  setContentData(null);
                }}
              >
                ← <Text>返回</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="DropdownMenuSeparator" />
              {loading && (
                <div className="LoadingContent">
                  <p>Loading...</p>
                </div>
              )}
              {error && (
                <div className="ErrorContent">
                  <p>Error: {error}</p>
                </div>
              )}
              {contentData && (
                <div className="ContentDisplay">
                  <h3>title</h3>
                  {/* @ts-ignore */}
                  <p>{JSON.stringify(contentData.args)}</p>
                </div>
              )}
            </>
          )}

          </DropdownMenu.Content>
        </DropdownMenu.Root>
      </div>
    </>
  );
};

export default BookDetailPage;
