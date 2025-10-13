"use client";

import React, { useState, useEffect, useRef, useContext } from 'react';
import { useParams, useSearchParams } from 'next/navigation';
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
import Head from 'next/head';

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

type BookMetaData = {
  title: string;
  author: string;
};

type BookDetailPageProps = {
  bookMeta: BookMetaData;
};

const BookDetailPage: React.FC = () => {
  const { id } = useParams();
  const searchParams = useSearchParams();
  const highlightText = searchParams.get('highlight');
  const contextParam = searchParams.get('context');
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
  }, [selectedFont, id, setFontFamily]);

  // This useEffect hook fetches the book data when the component mounts or when the id changes.
  useEffect(() => {
    if (id) {
      fetchBookData(id as string).then(setBook);
      addToBrowserHistory(id as string);
    }
  }, [id]); // Only depend on id
  
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
  }, [id, book]); // Only depend on id and book
  

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
  }, [selectedItem, selectedText]);


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
    const parts = document.querySelectorAll('p[id^="part-"]');
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
        if (visibleIds.length > 0) {
          setCurrentPartId(visibleIds[0]);
        }
      },
      { threshold: 0.01 }
    );

    parts.forEach(p => observer.observe(p));

    return () => {
      parts.forEach(p => observer.unobserve(p));
    };
  }, [book]); // Only depend on book

  // Track the last completed highlight to prevent double execution during same render
  const lastHighlightedRef = useRef<string>('');

  // Highlight search term and scroll to specific match by context
  useEffect(() => {
    if (!highlightText || !book) {
      return;
    }

    // Create a unique key for this highlight request
    const highlightKey = `${book.meta.id}-${highlightText}-${contextParam || ''}`;
    console.log('Highlight useEffect triggered', { highlightKey, lastHighlighted: lastHighlightedRef.current });

    // Skip if we already highlighted this exact combination
    if (lastHighlightedRef.current === highlightKey) {
      console.log('Already highlighted this exact search, skipping');
      return;
    }

    const container = recogitoContainerRef.current;
    if (!container) {
      console.log('Container not found');
      return;
    }

    let highlightApplied = false;

    // Use MutationObserver to wait for DOM to stabilize
    const observer = new MutationObserver(() => {
      // Check if we have article elements rendered
      const articles = container.querySelectorAll('article');
      if (articles.length > 0 && !highlightApplied) {
        highlightApplied = true;
        observer.disconnect();

        // Wait a bit more to ensure all Text components have rendered
        setTimeout(() => {
          applyHighlights();
        }, 300);
      }
    });

    observer.observe(container, {
      childList: true,
      subtree: true
    });

    // Fallback timeout in case MutationObserver doesn't trigger
    const fallbackTimer = setTimeout(() => {
      if (!highlightApplied) {
        highlightApplied = true;
        observer.disconnect();
        applyHighlights();
      }
    }, 2000);

    const applyHighlights = () => {
      const container = recogitoContainerRef.current;
      if (!container) {
        console.log('Container not found');
        return;
      }
      console.log('Starting highlight process');

      // Clear previous highlights by removing wrapper spans
      const previousWrappers = container.querySelectorAll('.search-highlighted');
      previousWrappers.forEach(wrapper => {
        const parent = wrapper.parentNode;
        if (parent) {
          // Move all child nodes out of the wrapper
          while (wrapper.firstChild) {
            parent.insertBefore(wrapper.firstChild, wrapper);
          }
          // Remove the empty wrapper
          parent.removeChild(wrapper);
        }
      });

      // Properly decode and normalize the search text
      const searchText = decodeURIComponent(highlightText).trim();

      // Get the fragment context from URL parameter
      const fragmentContext = searchParams.get('context')
        ? decodeURIComponent(searchParams.get('context')!)
        : null;

      // Normalize function to handle whitespace and punctuation variations
      // Replace symbols with underscore to match the context parameter format
      const normalize = (str: string) => str.replace(/[，。、；：！？""''（）【】《》\s]/g, '_');
      const normalizedSearch = normalize(searchText);
      const normalizedContext = fragmentContext ? normalize(fragmentContext) : null;

      const allMatches: { element: HTMLElement; context: string }[] = [];

      // Function to get surrounding context for a match
      const getContext = (element: HTMLElement, startParent?: HTMLElement | null): string => {
        // Start from the provided parent or traverse up from the element
        let current: HTMLElement | null = startParent || element;
        let paragraph: HTMLElement | null = null;

        // Find the containing paragraph element
        while (current) {
          if (current.tagName === 'P') {
            paragraph = current;
            break;
          }
          if (current.tagName === 'ARTICLE') {
            return element.textContent || '';
          }
          current = current.parentElement;
        }

        if (!paragraph) {
          return element.textContent || '';
        }

        // Collect text from previous paragraphs (up to 3)
        let beforeText = '';
        let prevPara = paragraph.previousElementSibling;
        for (let i = 0; i < 3 && prevPara; i++) {
          beforeText = (prevPara.textContent || '') + beforeText;
          prevPara = prevPara.previousElementSibling;
        }

        // Get current paragraph text
        const currentText = paragraph.textContent || '';

        // Collect text from next paragraphs (up to 3)
        let afterText = '';
        let nextPara = paragraph.nextElementSibling;
        for (let i = 0; i < 3 && nextPara; i++) {
          afterText = afterText + (nextPara.textContent || '');
          nextPara = nextPara.nextElementSibling;
        }

        return beforeText + currentText + afterText;
      };

      // Function to recursively search and highlight text
      const highlightInElement = (element: HTMLElement) => {
        // Skip if already processed or is a script/style tag
        if (element.classList.contains('search-highlighted') ||
            element.tagName === 'SCRIPT' ||
            element.tagName === 'STYLE' ||
            element.tagName === 'MARK') {
          return;
        }

        // Process child nodes
        const childNodes = Array.from(element.childNodes);
        childNodes.forEach(node => {
          if (node.nodeType === Node.TEXT_NODE) {
            const text = node.textContent || '';
            const normalizedText = normalize(text);

            // Check if the normalized text contains the search term
            if (normalizedText.includes(normalizedSearch)) {
              // Find exact position in original text
              const searchIndex = text.indexOf(searchText);

              if (searchIndex !== -1) {
                // Create wrapper with highlighted text
                const wrapper = document.createElement('span');
                wrapper.className = 'search-highlighted';

                const before = text.substring(0, searchIndex);
                const match = text.substring(searchIndex, searchIndex + searchText.length);
                const after = text.substring(searchIndex + searchText.length);

                if (before) wrapper.appendChild(document.createTextNode(before));

                const mark = document.createElement('mark');
                mark.className = 'search-result-highlight';
                mark.style.backgroundColor = '#fef08a';
                mark.style.padding = '2px 0';
                mark.style.borderRadius = '2px';
                mark.style.fontWeight = 'bold';
                mark.textContent = match;
                wrapper.appendChild(mark);

                if (after) wrapper.appendChild(document.createTextNode(after));

                // Get the parent element before replacing the node
                const parentElement = node.parentNode;
                node.parentNode?.replaceChild(wrapper, node);

                // Store match with its context (pass both mark and parent for context)
                const contextStr = getContext(mark, parentElement as HTMLElement);
                allMatches.push({ element: mark, context: contextStr });
              }
            }
          } else if (node.nodeType === Node.ELEMENT_NODE) {
            highlightInElement(node as HTMLElement);
          }
        });
      };

      // Start highlighting from the article content
      const articles = container.querySelectorAll('article');
      console.log('Found articles to search:', articles.length);
      articles.forEach(article => {
        highlightInElement(article as HTMLElement);
      });
      console.log('Total matches found:', allMatches.length);

      // Mark as highlighted now that highlighting is complete
      lastHighlightedRef.current = highlightKey;

      // Find the target match
      let targetMatch: HTMLElement | null = null;

      if (normalizedContext && allMatches.length > 0) {
        // Find match by context similarity
        for (const match of allMatches) {
          const normalizedMatchContext = normalize(match.context);
          if (normalizedMatchContext.includes(normalizedContext)) {
            targetMatch = match.element;
            break;
          }
        }
      }

      // Fallback to first match if context matching fails
      if (!targetMatch && allMatches.length > 0) {
        targetMatch = allMatches[0].element;
      }

      // Scroll to the target match
      if (targetMatch) {
        console.log('Found target match, scrolling to it:', {
          text: targetMatch.textContent,
          context: normalizedContext,
          totalMatches: allMatches.length
        });
        setTimeout(() => {
          targetMatch.scrollIntoView({ behavior: 'smooth', block: 'center' });
          targetMatch.style.animation = 'pulse 1s ease-in-out 2';
          console.log('✅ Highlight and jump completed successfully');

          // Check if highlights still exist in DOM after scrolling
          setTimeout(() => {
            const remainingHighlights = container.querySelectorAll('.search-result-highlight');
            console.log('Highlights still in DOM after scroll:', remainingHighlights.length);
            if (remainingHighlights.length === 0) {
              console.error('❌ All highlights were removed from DOM!');
            } else {
              console.log('First highlight element:', remainingHighlights[0], 'Styles:', (remainingHighlights[0] as HTMLElement).style.cssText);
            }
          }, 1000);
        }, 200);
      } else {
        console.log('⚠️ No target match found', {
          searchText,
          context: fragmentContext,
          totalMatches: allMatches.length
        });
      }
    };

    return () => {
      observer.disconnect();
      clearTimeout(fallbackTimer);
      // Don't clear the ref here - it persists to prevent double execution
      // It will be naturally cleared when component unmounts (ref resets to initial value)
    };
  }, [highlightText, contextParam, book]);
  
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
    <main>
      <style jsx global>{`
        @keyframes pulse {
          0%, 100% {
            background-color: #fef08a;
          }
          50% {
            background-color: #fde047;
          }
        }
      `}</style>
      <Header />
      <section  
        id="recogito-container"
        ref={recogitoContainerRef}
        className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8"
        style={{ fontFamily }}
        onMouseUp={handleTextSelection}
        onTouchStart={handleTouchStart}      
        onTouchEnd={handleTouchEnd}          
        onTouchMove={handleTouchEnd}         
        onContextMenu={handleContextMenu}
      >
        <header className="mb-4">
          <h1 className="text-3xl"><Text>{book.meta.title}</Text></h1>
          <h2 className="text-xl text-center p-6"><Text>{book.meta.Arthur}</Text></h2>
        </header>
        <article className={`${fontSize} ${selectedWidth}`} style={{ fontFamily }}>
          {book.juans.map((juan: any) => {
            if (juan.type === 'bt') {
              return (
                <section key={juan.id} id={juan.id} className="mb-8">
                  <h2 className="text-center text-2xl">
                    <Text>{juan.content[0]}</Text>
                  </h2>
                </section>
              );
            } else if (juan.type === 'bm') {
              return (
                <section key={juan.id} id={juan.id} className="mb-8">
                  <h4 className="text-center text-lg">
                    <Text>{juan.content[0]}</Text>
                  </h4>
                </section>
              );
            } else if (juan.type === 'p') {
              return (
                <article key={juan.id} id={juan.id} className="mb-8">
                  {juan.content.map((content: any, index: number) => (
                    <React.Fragment key={index}>
                      <p id={`part-${juan.id}-${index}`} className="inline-block pt-3">
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
                      </p>
                      <br />
                    </React.Fragment>
                  ))}
                </article>
              );
            }
            return null;
          })}
        </article>
      </section>

      {/* Context Menu */}
      <div onContextMenu={handleContextMenu} className="relative" ref={contextMenuRef}>
        <DropdownMenu.Root open={!!contextMenuPosition} modal={false}>
          <DropdownMenu.Trigger asChild>
            <button className="hidden" aria-label="Open context menu" />
          </DropdownMenu.Trigger>
          <DropdownMenu.Content
            sideOffset={5}
            style={{
              position: 'absolute',
              top: contextMenuPosition?.y,
              left: contextMenuPosition?.x,
              scrollbarWidth: 'thin',
              scrollbarColor: 'rgba(136, 136, 136, 0.8) transparent',
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
                aria-label="Copy text"
              >
                <Text>复制</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleSearch}
                aria-label="Search text"
              >
                <Text>搜索</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleDictionary}
                aria-label="Lookup dictionary"
              >
                <Text>字典</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleToModernChinese}
                aria-label="Translate to modern Chinese"
              >
                <Text>今译</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleExplain}
                aria-label="Explain text"
              >
                <Text>释义</Text>
              </DropdownMenu.Item>
              <DropdownMenu.Separator className="h-px my-1 bg-border" />
              <DropdownMenu.Item
                className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none focus:bg-accent focus:text-accent-foreground whitespace-nowrap"
                onSelect={handleAnnotate}
                aria-label="Annotate text"
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
                aria-label="Go back to main menu"
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

      {/* Footer Navigation */}
      <footer id="book-footer" className="flex flex-col space-y-2 items-center">
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
      </footer>

    </main>
  );
};

export default () => {
  return (
    <BookProvider>
      <AnnotationProvider>
        <BookDetailPage/>
      </AnnotationProvider>
    </BookProvider>
  );
};
