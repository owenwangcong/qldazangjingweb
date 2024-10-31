"use client";

import React, { useState, useContext } from 'react';
import { usePathname } from 'next/navigation';
import { Settings, ChevronDown, ChevronUp, Heart, Book, Download, Home, Search, Sun, Maximize } from 'lucide-react';
import Link from "next/link";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogClose } from "@/components/ui/dialog";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Label } from "@/components/ui/label";
import { Button } from '@/components/ui/button';
import * as Slider from '@radix-ui/react-slider';
import { BookContext } from '../context/BookContext';

import Text from './Text';
import { useLanguage } from '../context/LanguageContext';
import { useTheme, Theme } from '../context/ThemeContext';
import { useFont, FontContext } from '../context/FontContext';
import { useMyStudy } from '../context/MyStudyContext';

const Header: React.FC = () => {
  const pathname = usePathname();
  const [isHeaderVisible, setIsHeaderVisible] = useState(true);
  const { selectedFont, setSelectedFont, fontSize, setFontSize, selectedWidth, setSelectedWidth, fontFamily, setFontFamily } = useFont();
  const { book } = useContext(BookContext);
  const { favoriteBooks, addFavoriteBook, removeFavoriteBook, addBookmark, currentPartId } = useMyStudy();

  const { isSimplified, toggleLanguage } = useLanguage();
  const { theme, setTheme } = useTheme();

  const toggleHeaderVisibility = () => {
    setIsHeaderVisible(!isHeaderVisible);
  };

  const isBookPage = pathname.startsWith('/books/');

  const handleToggleLanguage = () => {
    toggleLanguage();
  };

  const handleThemeChange = (newTheme: Theme) => {
    setTheme(newTheme);
  };
  
  const handleJuanSelect = (juan: any) => {
    console.log(juan.id + " selected");
    const element = document.getElementById(juan.id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const toggleFavoriteBook = () => {
    if (book) {
      const isFavorited = favoriteBooks.some(fav => fav.bookId === book.meta.id);
      if (isFavorited) {
        console.log("Remove from Favorites:" + book.meta.id);
        removeFavoriteBook(book.meta.id);
      } else {
        console.log("Add to Favorites:" + book.meta.id);
        addFavoriteBook(book.meta.id);
      }
    }
  };

  // Helper functions to map between font size classes and slider values
  const fontSizeOptions = ['text-base', 'text-lg', 'text-xl', 'text-2xl', 'text-3xl', 'text-4xl', "text-5xl"];

  const fontSizeToNumber = (fontSizeClass: string): number => {
    return fontSizeOptions.indexOf(fontSizeClass);
  };

  const numberToFontSize = (value: number): string => {
    return fontSizeOptions[value] || 'text-base';
  };

  // Define width options
  const widthOptions = ['max-w-2xl', 'max-w-3xl', 'max-w-4xl', 'max-w-5xl', 'max-w-6xl', 'max-w-7xl'];
  
  const widthToNumber = (widthClass: string): number => {
    return widthOptions.indexOf(widthClass);
  };

  const numberToWidth = (value: number): string => {
    return widthOptions[value] || 'max-w-4xl';
  };

  const handleAddBookmark = () => {
    if (book && currentPartId) {
          // Start of Selection
          const part = document.getElementById(currentPartId);
          const content = part?.innerText.slice(0, 16) || '';
          addBookmark(book.meta.id, currentPartId, content);
          console.log('Bookmarked part:', content);
    } else {
      console.log('No paragraph to bookmark.');
    }
  };

  return (
    <div className="bg-background text-foreground">
        <div className="fixed top-2 right-2 space-y-4 z-50 flex flex-col">

        <button
          onClick={toggleHeaderVisibility}
          className="p-2 bg-card rounded-full shadow-md focus:outline-none hover:bg-primary-hover hover:text-primary-foreground-hover"
          aria-label={isHeaderVisible ? "Hide Header" : "Show Header"}
        >
          {isHeaderVisible ? 
            <div className="w-5 h-5">隐</div> : 
            <div className="w-5 h-5">显</div>
          }
        </button>

        {isHeaderVisible && (
          <>
            <DropdownMenu.Root modal={false}>
              <DropdownMenu.Trigger asChild>
                <button
                  className="p-2 bg-card rounded-full shadow-md focus:outline-none hover:bg-primary-hover hover:text-primary-foreground-hover"
                  aria-label="Select Theme"
                >
                  <div className="w-5 h-5">色</div>
                </button>
              </DropdownMenu.Trigger>
                      <DropdownMenu.Content className="bg-popover p-4 rounded-md shadow-lg">
                        {[
                          { value: 'lianchichanyun', label: '莲池禅韵' },
                          { value: 'zhulinyoujing', label: '竹林幽径' },
                          { value: 'yueyingqinghui', label: '月影清辉' },
                          { value: 'sangaijingtu', label: '伞盖净土' },
                          { value: 'guchayese', label: '古刹夜色' },
                          { value: 'fagufanyin', label: '法鼓梵音' },
                        ].map((theme, index) => (
                          <React.Fragment key={theme.value}>
                            <DropdownMenu.Item
                              onSelect={() => handleThemeChange(theme.value as Theme)}
                              className="flex items-center px-4 py-2 cursor-pointer text-lg hover:bg-primary-hover hover:text-primary-foreground-hover hover:border-none"
                            >
                              <Text>{theme.label}</Text>
                            </DropdownMenu.Item>
                            {index < 5 && <DropdownMenu.Separator className="my-2 h-px bg-border" />}
                          </React.Fragment>
                        ))}
                      </DropdownMenu.Content>
            </DropdownMenu.Root>

            <button
              onClick={handleToggleLanguage}
              className="p-2 bg-card rounded-full shadow-md focus:outline-none hover:bg-primary-hover hover:text-primary-foreground-hover"
              aria-label={isSimplified ? "Switch to Traditional Chinese" : "Switch to Simplified Chinese"}
            >
              {isSimplified ? (
                <div className="w-5 h-5">繁</div>
              ) : (
                <div className="w-5 h-5">简</div>
              )}
            </button>
            
            <Dialog modal={false}>
              <DialogTrigger asChild>
                <button
                  className="p-2 bg-card rounded-full shadow-md focus:outline-none hover:bg-primary-hover hover:text-primary-foreground-hover"
                  aria-label="Select Font and Width"
                >
                  <div className="w-5 h-5 flex items-center justify-center">
                  <div className="w-5 h-5">字</div>
                  </div>
                </button>
              </DialogTrigger>
              <DialogContent className="p-6 bg-card max-w-md md:max-w-lg lg:max-w-xl mx-auto max-h-[80vh] overflow-y-auto">
                <DialogHeader>
                  <DialogTitle><Text>选择字体和宽度</Text></DialogTitle>
                  <DialogDescription>
                    <Text>请选择一种字体、字体大小和内容宽度</Text>
                  </DialogDescription>
                </DialogHeader>
                <RadioGroup value={selectedFont} onValueChange={setSelectedFont} className="mt-4">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-aakai" id="aakai-font" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-aakai)` }} htmlFor="aakai-font">Aa楷体</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-aakaiSong" id="aaKaiSongFont" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-aakaiSong)` }} htmlFor="aaKaiSongFont">Aa楷宋</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-hyfs" id="hyfangsongFont" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-hyfs)` }} htmlFor="hyfangsongFont">汉仪仿宋</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-lxgw" id="lxgwFont" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-lxgw)` }} htmlFor="lxgwFont">落霞孤鹜</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-qnlb" id="qingniaolibianFont" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-qnlb)` }} htmlFor="qingniaolibianFont">青鸟隶变</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-rzykt" id="ruiziyunFont" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-rzykt)` }} htmlFor="ruiziyunFont">锐字云楷体</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-twzk" id="taiwanzhengkaiFont" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-twzk)` }} htmlFor="taiwanzhengkaiFont">台湾正楷体</Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <RadioGroupItem value="--font-wqwh" id="wenquanweiheiFont" />
                      <Label className="text-2xl" style={{ fontFamily: `var(--font-wqwh)` }} htmlFor="wenquanweiheiFont">文泉微黑</Label>
                    </div>
                  </div>
                </RadioGroup>
                
                <div className="mt-6">
                  <label className="text-sm font-medium mb-2">
                    <Text>字体大小</Text>
                  </label>
                  <Slider.Root
                    className="relative flex items-center select-none touch-none w-full h-5"
                    value={[fontSizeToNumber(fontSize)]}
                    min={0}
                    max={fontSizeOptions.length - 1}
                    step={1}
                    onValueChange={(value) => setFontSize(numberToFontSize(value[0]))}
                    aria-label="Font Size Slider"
                  >
                    <Slider.Track className="bg-secondary relative flex-1 h-1 rounded-full">
                      <Slider.Range className="absolute bg-primary h-full rounded-full" />
                    </Slider.Track>
                    <Slider.Thumb className="block w-4 h-4 bg-primary rounded-full focus:outline-none" />
                  </Slider.Root>
                  <div className="flex justify-between text-sm mt-2">
                    <span className="text-sm"><Text>小</Text></span>
                    <span className="text-xl"><Text>大</Text></span>
                  </div>
                </div>

                <div className="mt-6">
                  <label className="text-sm font-medium mb-2">
                    <Text>内容宽度</Text>
                  </label>
                  <Slider.Root
                    className="relative flex items-center select-none touch-none w-full h-5"
                    value={[widthToNumber(selectedWidth)]}
                    min={0}
                    max={widthOptions.length - 1}
                    step={1}
                    onValueChange={(value) => setSelectedWidth(numberToWidth(value[0]))}
                    aria-label="Content Width Slider"
                  >
                    <Slider.Track className="bg-secondary relative flex-1 h-1 rounded-full">
                      <Slider.Range className="absolute bg-primary h-full rounded-full" />
                    </Slider.Track>
                    <Slider.Thumb className="block w-4 h-4 bg-primary rounded-full focus:outline-none" />
                  </Slider.Root>
                  <div className="flex justify-between text-sm mt-2">
                    <span className="text-base"><Text>窄</Text></span>
                    <span className="text-base"><Text>宽</Text></span>
                  </div>
                </div>

                <div className="mt-6 flex justify-end">
                  <DialogClose asChild>
                    <Button className="hover:bg-primary-hover hover:text-primary-foreground-hover">
                      <Text>确定</Text>
                    </Button>
                  </DialogClose>
                </div>
              </DialogContent>
            </Dialog>

            {isBookPage && (
              <DropdownMenu.Root modal={false}>
                <DropdownMenu.Trigger asChild>
                  <button
                    className="p-2 bg-card rounded-full shadow-md focus:outline-none hover:bg-primary-hover hover:text-primary-foreground-hover"
                    aria-label="Select Theme"
                  >
                    <div className="w-5 h-5">目</div>
                  </button>
                </DropdownMenu.Trigger>
                <DropdownMenu.Content 
                  className="bg-popover p-4 rounded-md shadow-lg max-h-80 overflow-y-auto"
                  style={{ fontFamily }}
                >
                  {book?.juans.filter(juan => juan.name.trim() !== '').map((juan) => (
                    <React.Fragment key={juan.id}>
                      <DropdownMenu.Item
                        onSelect={() => handleJuanSelect(juan)}
                        className="flex items-center px-4 py-2 cursor-pointer text-lg hover:bg-primary-hover hover:text-primary-foreground-hover hover:border-none"
                      >
                        <Text>{juan.name}</Text>
                      </DropdownMenu.Item>
                      <DropdownMenu.Separator className="my-2 h-px bg-border" />
                    </React.Fragment>
                  ))}
                </DropdownMenu.Content>
              </DropdownMenu.Root>
            )}

            {isBookPage && (
              <button
                onClick={toggleFavoriteBook}
                className={`p-2 bg-card rounded-full shadow-md focus:outline-none hover:bg-primary-hover hover:text-primary-foreground-hover ${
                  book && favoriteBooks.some(fav => fav.bookId === book?.meta?.id) ? 'bg-secondary' : 'bg-card'
                }`}
                aria-label="Add to Favorites"
              >
                <div className="w-5 h-5">藏</div>
              </button>
            )}

            {isBookPage && (
              <button
                onClick={handleAddBookmark}
                className={`p-2 bg-card rounded-full shadow-md focus:outline-none hover:bg-primary-hover hover:text-primary-foreground-hover
                }`}
                aria-label="Add to Bookmarks"
              >
                <div className="w-5 h-5">签</div>
              </button>
            )}

          </>
        )}

      </div>  

      <div className={`transition-all duration-500 ${isHeaderVisible ? 'max-h-screen opacity-100' : 'max-h-0 opacity-0 overflow-hidden'}`}>
        <header className="w-full p-2">
          <nav className="flex flex-col md:flex-row justify-center items-center mx-auto p-5">
            <div className="flex-1 text-center">
              <h1 className="text-5xl font-bold"><Text>乾隆大藏经</Text></h1>
            </div>
          </nav>

          <div className="flex justify-center text-md py-4 text-xl">
            <nav className="flex flex-wrap justify-center w-full gap-4">
              <Link href="/" className={`flex items-center px-4 py-2 rounded-md border border-border hover:bg-primary-hover hover:text-primary-foreground-hover`}>
                <Home className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>首页</Text>
              </Link>
              <Link href="/search" className={`flex items-center px-4 py-2 rounded-md border border-border hover:bg-primary-hover hover:text-primary-foreground-hover`}>
                <Search className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>搜索</Text>
              </Link>
              <Link href="/dicts" className={`flex items-center px-4 py-2 rounded-md border border-border hover:bg-primary-hover hover:text-primary-foreground-hover`}>
                <Book className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>辞典</Text>
              </Link>
              <Link href="/mystudy" className={`flex items-center px-4 py-2 rounded-md border border-border hover:bg-primary-hover hover:text-primary-foreground-hover`}>
                <Heart className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>我的书房</Text>
              </Link>
            </nav>
          </div>
        </header>
      </div>
    </div>
  );
};

export default Header;
