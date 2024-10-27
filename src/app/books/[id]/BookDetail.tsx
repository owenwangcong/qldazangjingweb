// src/app/components/BookDetail.tsx
"use client";

import React, { useState, useEffect, useRef, useContext } from 'react';
import { useParams } from 'next/navigation';
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { FontContext } from '@/app/context/FontContext';
import Text from '@/app/components/Text';
import { ArrowLeft } from 'lucide-react';
import classNames from 'classnames';
import { Annotation, Recogito } from '@/app/scripts/recogito.min.js';
import ReactMarkdown from 'react-markdown';
import { AnnotationProvider, useAnnotations } from '@/app/context/AnnotationContext';

enum MenuItem {
  LookupDictionary = "lookupdictionary",
  ToModernChinese = "tomodernchinese",
  Explain = "explain"
}

interface ExtendedAnnotation extends Annotation {
  text: string;
  bookId: string;
}

const BookDetail: React.FC = () => {
  const { id } = useParams();
  const [book, setBook] = useState<any>(null);
  const [selectedText, setSelectedText] = useState<string>('');
  const [contextMenuPosition, setContextMenuPosition] = useState<{ x: number, y: number } | null>(null);
  const contextMenuRef = useRef<HTMLDivElement>(null);
  const { selectedFont, fontSize, selectedWidth } = useContext(FontContext);
  const [menuLevel, setMenuLevel] = useState('main');
  const [selectedItem, setSelectedItem] = useState<MenuItem | null>(null);
  const [contentData, setContentData] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [fontFamily, setFontFamily] = useState<string>('inherit');
  const recogitoContainerRef = useRef<HTMLDivElement>(null);
  const { annotations, addAnnotation, removeAnnotation } = useAnnotations();

  useEffect(() => {
    if (!book) return;

    let recogitoInstance: Recogito | null = null;

    const initializeRecogito = async () => {

      if (typeof window === "undefined") return;

      if (!recogitoContainerRef.current) return;

      const { Recogito } = await import('@/app/scripts/recogito.min.js');

      recogitoInstance = new Recogito({
        content: recogitoContainerRef.current,
        mode: 'html',
        locale: 'zh',
      });

      annotations.forEach(annotation => {
        if (annotation.bookId === id) {
          recogitoInstance?.addAnnotation(annotation);
        }
      });

      (recogitoInstance as any).on('createAnnotation', (annotation: ExtendedAnnotation) => {
        const bookId = Array.isArray(id) ? id[0] : id;
        addAnnotation(annotation, bookId);
      });

      (recogitoInstance as any).on('deleteAnnotation', (annotation: ExtendedAnnotation) => {
        const bookId = Array.isArray(id) ? id[0] : id;
        removeAnnotation(annotation.id, bookId);
      });
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
      document.removeEventListener('DOMContentLoaded', onDocumentReady);
      if (recogitoInstance) {
        try {
          recogitoInstance.destroy();
        } catch (error) {
          console.log('Error during Recogito instance destruction:', error);
        }
      }
    };
  }, [id, book]);

  useEffect(() => {
    if (id) {
      fetchBookData(id as string).then(setBook);
    }
  }, [id]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
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

    setMenuLevel('content');
    setLoading(true);
    setError(null);

    const fetchData = async () => {
      const payload = {
        //text: selectedText,
        //action: selectedItem.toString()
        prompt: "I say hello you should say?"
      };

      try {
        const response = await fetch('https://a5axo76waf.execute-api.ca-central-1.amazonaws.com/ToChatGPT', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify(payload),
        });

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error || 'Network response was not ok');
        }

        const data = await response.json();
        if (data.openai_response?.error?.message) {
          setContentData("大语言模型接口出现了一个问题。请联系管理员");
        } else {
          setContentData(data.openai_response?.choices?.[0]?.message?.content);
        }
      } catch (error: any) {
        setError(error.message);
        console.error('Error fetching data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [selectedItem]);

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
      return response.default;
    } catch (error) {
      console.error("Error fetching font data:", error);
      return null;
    }
  };

  const handleTextSelection = () => {
    const selection = window.getSelection();
    if (selection && selection.toString().trim()) {
      setSelectedText(selection.toString());
    } else {
      setSelectedText("");
      setContextMenuPosition(null);
    }
  };

  const handleContextMenu = (event: React.MouseEvent) => {
    const selection = window.getSelection();
    if (selection && selection.toString().trim()) {
      event.preventDefault();
      const clientX = event.clientX;
      const clientY = event.clientY;
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
  };

  const handleMenuClose = () => {
    setContextMenuPosition(null);
    setMenuLevel('main');
    setSelectedItem(null);
    setContentData(null);
  };

  const handleCopy = () => {
    if (selectedText) {
      navigator.clipboard.writeText(selectedText);
    }
    handleMenuClose();
  };

  const handleSearch = () => {
    if (selectedText) {
      const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(selectedText)}`;
      window.open(searchUrl, '_blank');
    }
    handleMenuClose();
  };

  const handleDictionary = () => {
    setSelectedItem(MenuItem.LookupDictionary);
  };

  const handleFavorite = () => {
    if (selectedText) {
      // Implement favorite logic here
    }
    handleMenuClose();
  };

  const handleToModernChinese = () => {
    setSelectedItem(MenuItem.ToModernChinese);
  };

  const handleExplain = () => {
    setSelectedItem(MenuItem.Explain);
  };

  const handleAnnotate = () => {
    if (selectedText) {
      const contentElement = document.getElementById('recogito-container');
      const event = new Event('trigger-selection');
      contentElement?.dispatchEvent(event);
    }
    handleMenuClose();
  };

  if (!book) {
    return (
      <div>
        <div className="flex justify-center items-center h-screen">
          <h1 className="text-3xl font-bold">Book not found</h1>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div
        id="recogito-container"
        ref={recogitoContainerRef}
        className={`flex flex-col items-center justify-center min-h-screen p-8 pb-10 gap-10 sm:p-10`}
        style={{ fontFamily }}
        onMouseUp={handleTextSelection}
        onContextMenu={handleContextMenu}
      >
        <h1 className="text-3xl font-bold"><Text>{book.meta.title}</Text></h1>
        <h2 className="text-xl"><Text>{book.meta.Arthur}</Text></h2>
        <div className={`${fontSize} ${selectedWidth}`} style={{ fontFamily }}>
          {book.juans.map((juan: any, juanIndex: number) => (
            <div key={juan.id || `juan-${juanIndex}`} className="mb-8">
              <h3 className="font-semibold"><Text>{juan.name}</Text></h3>
              {juan.chapters.map((chapter: any, chapterIndex: number) => (
                <div key={chapter.id || `chapter-${juanIndex}-${chapterIndex}`} className="mt-4">
                  <h4 className="font-medium"><Text>{chapter.name}</Text></h4>
                  {chapter.paragraphs.map((paragraph: string, paragraphIndex: number) => (
                    <p key={`paragraph-${juanIndex}-${chapterIndex}-${paragraphIndex}`} className="mt-5 mb-5 leading-normal">
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
                'w-80 h-64 overflow-auto font-sans': menuLevel === 'content'
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
    </div>
  );
};

export default BookDetail;
