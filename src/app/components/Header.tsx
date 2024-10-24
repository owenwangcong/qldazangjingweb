"use client";

import React, { useState, useEffect, useContext } from 'react';
import { usePathname } from 'next/navigation';
import { Settings, ChevronDown, ChevronUp, Heart, Book, Download, Home, Search, RefreshCcw, FileType, Sun, Moon, Droplet, Circle, Zap } from 'lucide-react';
import Link from "next/link";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Label } from "@/components/ui/label";
import { FontContext } from '../context/FontContext';
import { Button } from '@/components/ui/button';
import { DialogClose } from '@/components/ui/dialog';
import Text from './Text';
import { useLanguage } from '../context/LanguageContext';
import { useTheme, Theme } from '../context/ThemeContext';

const Header: React.FC = () => {
  const pathname = usePathname();
  const [isHeaderVisible, setIsHeaderVisible] = useState(true);
  const { selectedFont, setSelectedFont } = useContext(FontContext);
  const { isSimplified, toggleLanguage } = useLanguage();
  const { theme, setTheme } = useTheme();

  const toggleHeaderVisibility = () => {
    setIsHeaderVisible(!isHeaderVisible);
  };

  const isBookPage = pathname.startsWith('/books/');

  // Update the toggleLanguage function to use context's toggleLanguage
  const handleToggleLanguage = () => {
    console.log("handleToggleLanguage");
    toggleLanguage();
  };

  const handleThemeChange = (newTheme: Theme) => {
    setTheme(newTheme);
  };

  return (
    <div>
      <div className="fixed top-2 right-2 space-x-4">
        
        <button
          onClick={toggleHeaderVisibility}
          className="p-2 bg-gray-200 rounded-full shadow-md focus:outline-none"
          aria-label={isHeaderVisible ? "Hide Header" : "Show Header"}
        >
          {isHeaderVisible ? <ChevronUp className="w-5 h-5" aria-hidden="true" /> : <ChevronDown className="w-5 h-5" aria-hidden="true" />}
        </button>

        <DropdownMenu.Root modal={false}>
          <DropdownMenu.Trigger asChild>
            <button
              className="p-2 bg-gray-200 rounded-full shadow-md focus:outline-none"
              aria-label="Select Theme"
            >
              <Sun className="w-5 h-5" />
            </button>
          </DropdownMenu.Trigger>
          <DropdownMenu.Content className="bg-white dark:bg-gray-800 p-2 rounded-md shadow-lg">
            <DropdownMenu.Item onSelect={() => handleThemeChange('lianchichanyun')} className="flex items-center px-2 py-1 cursor-pointer">
              <Text>莲池禅韵</Text>
            </DropdownMenu.Item>
            <DropdownMenu.Item onSelect={() => handleThemeChange('zhulinyoujing')} className="flex items-center px-2 py-1 cursor-pointer">
              <Text>竹林幽径</Text>
            </DropdownMenu.Item>
            <DropdownMenu.Item onSelect={() => handleThemeChange('yueyingqinghui')} className="flex items-center px-2 py-1 cursor-pointer">
              <Text>月影清辉</Text>  
            </DropdownMenu.Item>
            <DropdownMenu.Item onSelect={() => handleThemeChange('sangaijingtu')} className="flex items-center px-2 py-1 cursor-pointer">
              <Text>伞盖净土</Text>
            </DropdownMenu.Item>
            <DropdownMenu.Item onSelect={() => handleThemeChange('guchayese')} className="flex items-center px-2 py-1 cursor-pointer">
              <Text>古刹夜色</Text>
            </DropdownMenu.Item>
            <DropdownMenu.Item onSelect={() => handleThemeChange('fagufanyin')} className="flex items-center px-2 py-1 cursor-pointer">
              <Text>法鼓梵音</Text>
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Root>

        {/* {{ edit_3 }}
            Update the language toggle button to use handleToggleLanguage */}
        <button
          onClick={handleToggleLanguage}
          className="p-2 bg-gray-200 rounded-full shadow-md focus:outline-none"
          aria-label={isSimplified ? "Switch to Traditional Chinese" : "Switch to Simplified Chinese"}
        >
          {isSimplified ? (
            <svg className="w-5 h-5">
              <text x="50%" y="50%" fontSize="15" fontFamily="system-ui, sans-serif" textAnchor="middle" dominantBaseline="middle">繁</text>
            </svg>
          ) : (
            <svg className="w-5 h-5">
              <text x="50%" y="50%" fontSize="15" fontFamily="system-ui, sans-serif" textAnchor="middle" dominantBaseline="middle">简</text>
            </svg>
          )}
        </button>
        
        {/* Font Selection Button */}
        <Dialog>
          <DialogTrigger asChild>
            <button
              className="p-2 bg-gray-200 rounded-full shadow-md focus:outline-none"
              aria-label="Select Font"
            >
              <svg className="w-5 h-5">
                <text x="50%" y="50%" fontSize="15" fontFamily="system-ui, sans-serif" textAnchor="middle" dominantBaseline="middle">字</text>
              </svg>
            </button>
          </DialogTrigger>
          <DialogContent className="p-6">
            <DialogHeader>
              <DialogTitle><Text>选择字体</Text></DialogTitle>
              <DialogDescription>
                <Text>请选择一种字体</Text>
              </DialogDescription>
            </DialogHeader>
            <RadioGroup value={selectedFont} onValueChange={setSelectedFont} className="mt-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-aakai" id="aakai-font" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-aakai)`}} htmlFor="aakai-font">Aa楷体</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-aakaiSong" id="aaKaiSongFont" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-aakaiSong)`}} htmlFor="aaKaiSongFont">Aa楷宋</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-hyfs" id="hyfangsongFont" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-hyfs)`}} htmlFor="hyfangsongFont">汉仪仿宋</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-lxgw" id="lxgwFont" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-lxgw)`}} htmlFor="lxgwFont">落霞孤鹜</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-qnlb" id="qingniaolibianFont" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-qnlb)`}} htmlFor="qingniaolibianFont">青鸟隶变</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-rzykt" id="ruiziyunFont" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-rzykt)`}} htmlFor="ruiziyunFont">锐字云楷体</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-twzk" id="taiwanzhengkaiFont" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-twzk)`}} htmlFor="taiwanzhengkaiFont">台湾正楷体</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="--font-wqwh" id="wenquanweiheiFont" />
                  <Label className="text-2xl" style={{fontFamily: `var(--font-wqwh)`}} htmlFor="wenquanweiheiFont">文泉微黑</Label>
                </div>
              </div>
            </RadioGroup>
            <div className="mt-4 flex justify-end">
              <DialogClose asChild>
                <Button>
                  <Text>确定</Text>
                </Button>
              </DialogClose>
            </div>
          </DialogContent>
        </Dialog>
        

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
              <Link href="/" className="flex items-center px-4 py-2 rounded-md border border-gray-200 hover:bg-primary-hover hover:text-primary-foreground-hover">
                <Home className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>首页</Text>
              </Link>
              <Link href="/search" className="flex items-center px-4 py-2 rounded-md border border-gray-200 hover:bg-primary-hover hover:text-primary-foreground-hover">
                <Search className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>搜索</Text>
              </Link>
              <Link href="/dicts" className="flex items-center px-4 py-2 rounded-md border border-gray-200 hover:bg-primary-hover hover:text-primary-foreground-hover">
                <Book className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>词典</Text>
              </Link>
              <Link href="/favorites" className="flex items-center px-4 py-2 rounded-md border border-gray-200 hover:bg-primary-hover hover:text-primary-foreground-hover">
                <Heart className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>收藏</Text>
              </Link>
              <Link href="/downloads" className="flex items-center px-4 py-2 rounded-md border border-gray-200 hover:bg-primary-hover hover:text-primary-foreground-hover">
                <Download className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>下载</Text>
              </Link>
              <Link href="/settings" className="flex items-center px-4 py-2 rounded-md border border-gray-200 hover:bg-primary-hover hover:text-primary-foreground-hover">
                <Settings className="w-5 h-5 mr-3" aria-hidden="true" /> <Text>设置</Text>
              </Link>
            </nav>
          </div>
        </header>
      </div>
    </div>
  );
};

export default Header;
