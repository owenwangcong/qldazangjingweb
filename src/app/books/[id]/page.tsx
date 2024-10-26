"use client";

import React, { useState, useEffect, useRef, useContext } from 'react';
import { useParams } from 'next/navigation';
import Header from '@/app/components/Header';
import * as DropdownMenu from "@radix-ui/react-dropdown-menu"
import { FontContext } from '@/app/context/FontContext';
import Text from '@/app/components/Text';
import { ArrowLeft } from 'lucide-react';
import classNames from 'classnames'; // Import classNames for conditional classes
import { Recogito } from '@/app/scripts/recogito.min.js';

const BookDetailPage: React.FC = () => {
  const { id } = useParams();
  const [book, setBook] = useState<any>(null);
  const [selectedText, setSelectedText] = useState<string>('');
  const [contextMenuPosition, setContextMenuPosition] = useState<{ x: number, y: number } | null>(null);
  const contextMenuRef = useRef<HTMLDivElement>(null);
  const { selectedFont, setSelectedFont } = useContext(FontContext);
 
  const [menuLevel, setMenuLevel] = useState('main');
  const [selectedItem, setSelectedItem] = useState<string | null>(null);
  const [contentData, setContentData] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const [fontFamily, setFontFamily] = useState<string>('inherit');

  const recogitoContainerRef = useRef<HTMLDivElement>(null); // <-- Added useRef for recogito-container

  // Initialize Recogito when the component mounts or id/book changes
  useEffect(() => {
    // Only initialize Recogito when the book data is loaded
    if (!book) {
      console.log('Book data not loaded yet');
      return;
    }

    let recogitoInstance: Recogito | null = null;

    const initializeRecogito = () => {
      if (!recogitoContainerRef.current) {
        console.log('recogitoContainerRef.current is null');
        return;
      }

      recogitoInstance = new Recogito({
        content: recogitoContainerRef.current,
        mode: 'html',
        locale: 'zh',
      });

      console.log('Recogito instance created');
    };

    const onDocumentReady = () => {
      initializeRecogito();
    };

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      initializeRecogito();
    } else {
      document.addEventListener('DOMContentLoaded', onDocumentReady);
    }

    return () => {
      console.log('Returning from useEffect in recogitoContainer');

      document.removeEventListener('DOMContentLoaded', onDocumentReady);

      if (recogitoInstance) {
        console.log('Destroying Recogito instance');
        try {
          recogitoInstance.destroy();
        } catch (error) {
          console.log('Error during Recogito instance destruction:', error);
          // The node might have been removed already, so ignore the error
        }
      } else {
        console.log('Recogito instance is null');
      }
    };
  }, [id, book]); // Add 'book' to the dependency array
  

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

      const selectedFontName = fontMapping[selectedFontFamilyName] || 'lxgw';
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

      const clientX = event.clientX;
      const clientY = event.clientY;
      const MENU_HEIGHT = 320; // Estimated height of the dropdown menu in pixels

      const dropdownBottom = clientY + MENU_HEIGHT;
      const pageHeight = window.innerHeight;

      let adjustedY = clientY;
      if (dropdownBottom > pageHeight) {
        adjustedY = clientY - MENU_HEIGHT;
      }

      setContextMenuPosition({
        x: clientX,
        y: adjustedY,
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
  };

  // Define the handleShiYi function
  const handleExplain = () => {
    setSelectedItem("explain")
    if (selectedText) {
      console.log('Interpretation for:', selectedText);
      // Implement interpretation logic here
    }
  };

  // Define the handleAnnotate function
  const handleAnnotate = () => {
    if (selectedText) {
      console.log('Annotate:', selectedText);
      const contentElement = document.getElementById('recogito-container');
      const event = new Event('trigger-selection');
      contentElement?.dispatchEvent(event);
    }
    handleMenuClose();
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
    if (!selectedItem) return;

    setMenuLevel('content'); // Move to content view
    setLoading(true);
    setError(null);

    const fetchData = async () => {
      try {
        const response = await fetch('/api/translate', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            prompt: `把这段文字翻译成白话文：${selectedText}`,
          }),
        });

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error || 'Network response was not ok');
        }

        const data = await response.json();
        setContentData(data.openai_response?.choices?.[0]?.message?.content);
        console.log('Content data:', data);
      } catch (error: any) {
        setError(error.message);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
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
      <div>  {/* Replaced fragment with a div */}
        <Header />
        <div className="flex justify-center items-center h-screen">
          <h1 className="text-3xl font-bold">{/* <Text>Book not found</Text> */}</h1>
        </div>
      </div>
    );
  }

  return (
    <div>  {/* Replaced fragment with a div */}
      <Header />
      <div
        id="recogito-container"
        ref={recogitoContainerRef}
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

      {/* Context Menu */}
      <div onContextMenu={handleContextMenu} className="relative" ref={contextMenuRef}>
        <DropdownMenu.Root open={!!contextMenuPosition} modal={false}>
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
            className={classNames(
              "bg-popover shadow-lg rounded-md p-2",
              {
                'w-64 h-64 overflow-auto font-sans': menuLevel === 'content'
              }
            )}
          >

          {menuLevel === 'main' && (
            <>
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleCopy}
              >
                <Text>复制</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleSearch}
              >
                <Text>搜索</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleDictionary}
              >
                <Text>字典</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleFavorite}
              >
                <Text>收藏</Text> 
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleToModernChinese}
              >
                <Text>今译</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleExplain}
              >
                <Text>释义</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleAnnotate}
              >
                <Text>注释</Text>
              </DropdownMenu.Item>
            </>
          )}
          {menuLevel === 'content' && (
            <>
              <DropdownMenu.Item
                className="flex items-center cursor-pointer select-none rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={() => {
                  setMenuLevel('main');
                  setSelectedItem(null);
                  setContentData(null);
                }}
              >
                <ArrowLeft className="w-5 h-5 mr-3" aria-hidden="true" /><Text>返回</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <div className="flex flex-col items-start overflow-auto">
                {loading && (
                  <div className="LoadingContent">
                    <p>加载中</p>
                  </div>
                )}
                {error && (
                  <div className="ErrorContent">
                    <p>出现了一个错误：{error}</p>
                  </div>
                )}
                {contentData && (
                  <div className="ContentDisplay">
                    <p>{JSON.stringify(contentData)}</p>
                  </div>
                )}
              </div>
            </>
          )}

          </DropdownMenu.Content>
        </DropdownMenu.Root>
      </div>
    </div>
  );
};

export default BookDetailPage;
