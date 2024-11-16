"use client";

import React, { useState, useEffect, useRef, useContext } from 'react';
import { useParams } from 'next/navigation';
import Header from '@/app/components/Header';
import * as DropdownMenu from "@radix-ui/react-dropdown-menu"
import { FontContext } from '@/app/context/FontContext';
import Text from '@/app/components/Text';
import { ArrowLeft } from 'lucide-react';
import Link from 'next/link';
import classNames from 'classnames'; // Import classNames for conditional classes
import { Annotation, Recogito } from '@/app/scripts/recogito.min.js';

import ReactMarkdown from 'react-markdown';
import { convertResultsToMarkdown } from '@/app/utils/convertResultsToMarkdown';
import { AnnotationProvider, useAnnotations } from '@/app/context/AnnotationContext';
import { BookContext, BookProvider } from '@/app/context/BookContext';
import { useMyStudy } from '@/app/context/MyStudyContext';

// Define the MenuItem enum
enum MenuItem {
  LookupDictionary = "lookupdictionary",
  ToModernChinese = "tomodernchinese",
  Explain = "explain"
}

// Define a new type that extends the existing Annotation type
interface ExtendedAnnotation extends Annotation {
  text: string; // Add the missing 'text' property
  bookId: string; // Add the 'bookId' property
}

const BookDetailPage: React.FC = () => {
  const { id } = useParams();
  const { book, setBook } = useContext(BookContext);
  const [selectedText, setSelectedText] = useState<string>('');
  const [contextMenuPosition, setContextMenuPosition] = useState<{ x: number, y: number } | null>(null);
  const contextMenuRef = useRef<HTMLDivElement>(null);
  const { selectedFont, fontSize, selectedWidth } = useContext(FontContext);
  const { fontFamily, setFontFamily } = useContext(FontContext);
 
  const [menuLevel, setMenuLevel] = useState('main');
  const [selectedItem, setSelectedItem] = useState<MenuItem | null>(null);
  const [contentData, setContentData] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const recogitoContainerRef = useRef<HTMLDivElement>(null); // Existing ref
  const { annotations, addAnnotation, removeAnnotation } = useAnnotations();

  const { addToBrowserHistory, currentPartId, setCurrentPartId } = useMyStudy();
  
  // Ref to store long-press timer
  const longPressTimerRef = useRef<number | null>(null);

  const LONG_PRESS_DURATION = 500; // Duration in ms for long press

  const [visiblePartIds, setVisiblePartIds] = useState<string[]>([]);

  // Fetch the book data based on the id
  const fetchBookData = async (id: string) => {
    try {
      const response = await fetch(`/data/books/${id}.json`);
      if (!response.ok) {
        throw new Error(`Failed to fetch book data: ${response.statusText}`);
      }
      const bookData = await response.json();
      return bookData;
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
      const response = await fetch(`/data/book_fonts/${selectedFontName}_${bookId}.woff`);
      if (!response.ok) {
        throw new Error(`Failed to fetch font: ${response.statusText}`);
      }
      const fontBlob = await response.blob();
      const fontUrl = URL.createObjectURL(fontBlob);
      console.log('Font URL:', fontUrl);
      return fontUrl;
    } catch (error) {
      console.error("Error fetching font data:", error);
      return null;
    }
  };

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

  // This useEffect hook fetches the book data when the component mounts or when the id changes.
  useEffect(() => {
    if (id) {
      fetchBookData(id as string).then(setBook);
      addToBrowserHistory(id as string);
    }
  }, [id]);
  
  // Initialize Recogito when the component mounts or id/book changes
  useEffect(() => {

    // Only initialize Recogito when the book data is loaded
    if (!book) {
      console.log('Book data not loaded yet');
      return;
    }

    let recogitoInstance: Recogito | null = null;

    const initializeRecogito = async () => {
      if (!recogitoContainerRef.current) {
        console.log('recogitoContainerRef.current is null');
        return;
      }

      // Dynamically import Recogito only on the client side
      const { Recogito } = await import('@/app/scripts/recogito.min.js');

      recogitoInstance = new Recogito({
        content: recogitoContainerRef.current,
        mode: 'html',
        locale: 'zh',
      });

      console.log('Recogito instance created');

      // Load existing annotations
      annotations.forEach(annotation => {
        if (annotation.bookId === id) {
          recogitoInstance?.addAnnotation(annotation);
        }
      });

      // Type assertion to bypass TypeScript error
      (recogitoInstance as any).on('createAnnotation', (annotation: ExtendedAnnotation) => {
        console.log('Adding annotation:', annotation);
        const bookId = Array.isArray(id) ? id[0] : id; // Ensure 'bookId' is a string
        addAnnotation(annotation, bookId);
      });

      // Type assertion to bypass TypeScript error
      (recogitoInstance as any).on('deleteAnnotation', (annotation: ExtendedAnnotation) => {
        console.log('Removing annotation:', annotation);
        const bookId = Array.isArray(id) ? id[0] : id; // Ensure 'bookId' is a string
        removeAnnotation(annotation.id, bookId); // Pass annotation.id directly
      });
    };

    const handleHashScroll = () => {
      const hash = window.location.hash;
      if (hash.startsWith('#part-')) {
        const elementId = hash.substring(1); // Remove the '#' character
        const targetElement = document.getElementById(elementId);
        console.log("scroll to part:", elementId);
        if (targetElement) {
          targetElement.scrollIntoView({ behavior: 'smooth' });
        }
      } else if (hash.startsWith('##')) {
        const dataId = hash.substring(1); // Remove the '##' characters
        const targetElement = document.querySelector(`[data-id="${dataId}"]`);
        console.log("scroll to data-id:", dataId);
        if (targetElement) {
          targetElement.scrollIntoView({ behavior: 'smooth' });
        }
      }
    };

    const onDocumentReady = () => {
      initializeRecogito();
      handleHashScroll();
    };

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      initializeRecogito();
      handleHashScroll();
    } else {
      document.addEventListener('load', onDocumentReady);
    }

    return () => {
      console.log('Returning from useEffect in recogitoContainer');

      document.removeEventListener('load', onDocumentReady);

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
  }, [id, book]); // Updated dependencies
  

  const handleTextSelection = (event: React.MouseEvent | React.TouchEvent) => {
    const selection = window.getSelection();
    if (selection && selection.toString().trim()) {
      const selected = selection.toString();
      console.log('Selected text:', selected); // Debug: Log selected text
      handleContextMenu(event);
    } else {
      console.log('No text selected'); // Debug: Log when no text is selected
      setContextMenuPosition(null);
    }
  };

  const handleContextMenu = (event: React.MouseEvent | React.TouchEvent) => {
    if (event.nativeEvent instanceof MouseEvent) {
      // Existing mouse event handling
      const selection = window.getSelection();
      if (selection && selection.toString().trim()) {
        event.preventDefault();
        const clientX = event.nativeEvent.clientX;
        const clientY = event.nativeEvent.clientY;
        const MENU_HEIGHT = 320;

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
    } else if (event.nativeEvent instanceof TouchEvent) {
      // New touch event handling
      const touch = event.nativeEvent.touches[0];
      const selection = window.getSelection();
      if (selection && selection.toString().trim()) {
        event.preventDefault();
        const clientX = touch.clientX;
        const clientY = touch.clientY;
        const MENU_HEIGHT = 320;

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

  const handleDictionary = async () => {
    setSelectedItem(MenuItem.LookupDictionary)    
  };

  const handleFavorite = () => {
    if (selectedText) {
      console.log('Marked as favorite:', selectedText);
      // Implement favorite logic here, e.g., save to local storage or a database
    }
    handleMenuClose();
  };

  // Define the handleToModernChinese function
  const handleToModernChinese = () => {
    setSelectedItem(MenuItem.ToModernChinese)
    if (selectedText) {
      console.log('Convert to Bai Hua Wen:', selectedText);
      // Implement Bai Hua Wen conversion logic here
    }
  };

  // Define the handleExplain function
  const handleExplain = () => {
    setSelectedItem(MenuItem.Explain)
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

  // Long press handlers

  const handleTouchStart = (event: React.TouchEvent) => {
    const touch = event.touches[0];
    longPressTimerRef.current = window.setTimeout(() => {
      if (selectedText.trim()) {
        setContextMenuPosition({ x: touch.clientX, y: touch.clientY });
      }
    }, LONG_PRESS_DURATION);
  };

  const handleTouchEnd = () => {
    if (longPressTimerRef.current) {
      clearTimeout(longPressTimerRef.current);
      longPressTimerRef.current = null;
    }
  };

  useEffect(() => {

    document.addEventListener('contextmenu', (e) => {
      console.log('right click!');
      e.preventDefault();//===added this===
      return false;
    });

    const handleSelectionChange = () => {
      const selection = window.getSelection();
      const selectedText = selection?.toString() || '';
      setSelectedText(selectedText);
      console.log('Selection Changed! - ', selectedText);
    };

    document.addEventListener('selectionchange', handleSelectionChange);

    return () => {
      document.removeEventListener('selectionchange', handleSelectionChange);
    };
  }, []);

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

      if(selectedItem === MenuItem.LookupDictionary){
        const payload = {
          "key" : selectedText
         };
        try {
          const response = await fetch("/api/todict/", {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
          });
  
          if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Network response was not ok');
          }
  
          const data = await response.json();
          console.log('data', data);
          if (data.results && data.results.length > 0) {
            setContentData(convertResultsToMarkdown(data.results));
          } else {
            setContentData("找不到字典解释");
          }
        } catch (error: any) {
          setError(error.message);
          console.error('Error fetching data:', error);
        } finally {
          setLoading(false);
        }
      }else if(selectedItem === MenuItem.ToModernChinese || selectedItem === MenuItem.Explain){
        const payload = {
          text: selectedText,
          action: selectedItem.toString()
        };
  
        try {
          const response = await fetch('/api/tochatgpt/', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload),
          });
  
          if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Network response was not ok');
          }
  
          const data = await response.json();
          if(data.openai_response?.error?.message){
            setContentData("大语言模型接口出现了一个问题。请联系管理员");
          } else {
            const warning = "**以下内容由AI生成, 仅供参考**\n\n";
            const content = data.openai_response?.choices?.[0]?.message?.content;
            const oversizeMessage = "\n\n\n\n**注意：由于查询内容较长，部分信息可能未显示。请适当减少查询字数。**";
            let finalContent = warning + content;
            if (data.openai_response?.usage?.completion_tokens >= 1024) {
              finalContent += oversizeMessage;
            }
            setContentData(finalContent);
          }
        } catch (error: any) {
          setError(error.message);
          console.error('Error fetching data:', error);
        } finally {
          setLoading(false);
        }
      }
    };
    fetchData();
  }, [selectedItem]);


  // Cleanup for long press timer on unmount
  useEffect(() => {
    return () => {
      if (longPressTimerRef.current) {
        clearTimeout(longPressTimerRef.current);
      }
    };
  }, []);

  // 滚动到选中的段落
  useEffect(() => {
    const parts = document.querySelectorAll('span[id^="part-"]');
    const visiblePartIdsSet = new Set<string>();
  
    const observer = new IntersectionObserver(
      (entries: IntersectionObserverEntry[]) => {
        entries.forEach(entry => {
          const id = entry.target.id;
          if (entry.isIntersecting) {
            visiblePartIdsSet.add(id);
          } else {
            visiblePartIdsSet.delete(id);
          }
        });
        const visibleIds = Array.from(visiblePartIdsSet);
        setVisiblePartIds(visibleIds);
        visibleIds.sort((a, b) => a.localeCompare(b));
        setCurrentPartId(visibleIds[0]);
      },
      { threshold: 0.01 }
    );
  
    parts.forEach(p => observer.observe(p));
  
    return () => {
      parts.forEach(p => observer.unobserve(p));
    };
  }, [book]);
  
  useEffect(() => {
    const originalTitle = document.title; // Store the original title

    if (book && book.meta && book.meta.title) {
      document.title = "乾隆大藏经 | " + book.meta.title; // Set the document title dynamically
    }

    return () => {
      document.title = originalTitle; // Restore the original title on unmount
    };
  }, [book]);

  if (!book) {
    return (
      <div>
        <Header />
        <div className="flex items-center h-screen">
          <h1 className="text-3xl font-bold">{/* <Text>Book not found</Text> */}</h1>
        </div>
      </div>
    );
  }

  return (
    <div>
      <Header />
      <div  
        id="recogito-container"
        ref={recogitoContainerRef}
        className={`flex flex-col items-center min-h-screen p-8 pb-8 gap-8`}
        style={{ fontFamily }}
        onMouseUp={handleTextSelection}
        onTouchStart={handleTouchStart}      
        onTouchEnd={handleTouchEnd}          
        onTouchMove={handleTouchEnd}         
        onContextMenu={handleContextMenu}
      >
        <h1 className="text-3xl"><Text>{book.meta.title}</Text></h1>
        <h2 className="text-xl"><Text>{book.meta.Arthur}</Text></h2>
        <div className={`${fontSize} ${selectedWidth}`} style={{ fontFamily }}>
              {book.juans.map((juan: any) => {
                if (juan.type === 'bt') {
                  return (
                    <div key={juan.id} id={juan.id} className="mb-8">
                      <h2 className="text-center text-2xl">
                        <Text>{juan.content[0]}</Text>
                      </h2>
                    </div>
                  );
                } else if (juan.type === 'bm') {
                  return (
                    <div key={juan.id} id={juan.id} className="mb-8">
                      <h4 className="text-center text-lg">
                        <Text>{juan.content[0]}</Text>
                      </h4>
                    </div>
                  );
                } else if (juan.type === 'p') {
                  return (
                    <p key={juan.id} id={juan.id} className="mb-8">
                      {juan.content.map((content: any, index: number) => (
                        <React.Fragment key={index}>
                          <span id={`part-${juan.id}-${index}`}
                            className="inline-block"
                            style={{ paddingTop: '12px' }}
                          >
                            {content.replace("“", '').replace("”", '').split(/(<img[^>]*>)/g).map((part: any, idx: number) => (
                              part.match(/<img[^>]*>/) ? (
                                <img
                                  key={idx}
                                  src={part.match(/src=["']([^"']+)["']/)?.[1] || ''}
                                  alt={`Image ${idx + 1}`}
                                  className="my-4"
                                />
                              ) : (
                                <span key={idx}><Text>{part}</Text></span>
                              )
                            ))}
                          </span>
                          <br />
                        </React.Fragment>
                      ))}
                    </p>
                  );
                }
                return null;
              })}
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
              scrollbarWidth: 'thin', 
              scrollbarColor: '#888 #f1f1f1',
              scrollbarGutter: 'stable both-edges',
            }}
            className={classNames(
              "bg-muted/85 backdrop-blur-sm shadow-lg rounded-md p-2",
              {
                'w-80 h-64 overflow-y-scroll scrollbar-thin font-sans': menuLevel === 'content'
              }
            )}
          >

          {menuLevel === 'main' && (
            <>
              <DropdownMenu.Item 
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-primary-foreground whitespace-nowrap"
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
                className="flex items-center cursor-pointer select-none rounded-sm px-3 py-1 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
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
                    {contentData ? (
                      <ReactMarkdown className="prose" children={contentData} />
                    ) : (
                      <p>没有内容</p>
                    )}
                  </div>
                )}
              </div>
            </>
          )}

          </DropdownMenu.Content>
        </DropdownMenu.Root>
      </div>

      {/* Last and next button */}
      <div className="flex flex-col space-y-2 items-center">
        {book.meta.last_bu && Object.keys(book.meta.last_bu).length > 0 && (
          <Link
            href={`/books/${book.meta.last_bu.id}`}
            className="text-[hsl(var(--primary))] p-2"
            aria-label={`Navigate to previous book: ${book.meta.last_bu.name}`}
          >
            <Text>{`${book.meta.last_bu.name}`}</Text>
          </Link>
        )}
        {book.meta.next_bu && Object.keys(book.meta.next_bu).length > 0 && (
          <Link
            href={`/books/${book.meta.next_bu.id}`}
            className="text-[hsl(var(--primary))] p-2 pb-10"
            aria-label={`Navigate to next book: ${book.meta.next_bu.name}`}
          >
            <Text>{`${book.meta.next_bu.name}`}</Text>
          </Link>
        )}
      </div>

    </div>
  );
};

export default () => (
  <BookProvider>
    <AnnotationProvider>
      <BookDetailPage />
    </AnnotationProvider>
  </BookProvider>
);
