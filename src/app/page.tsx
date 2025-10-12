"use client";

import React, { useState, useEffect } from 'react';
import Header from './components/Header';
import { ClassicTextsContent, loadClassicTexts, ClassicTexts as ClassicTextsType } from './components/ClassicTexts';
import Link from 'next/link';
import { FontContext } from './context/FontContext';
import Text from '@/app/components/Text';
import Head from 'next/head';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

interface MlsItem {
  id: string;
  name: string;
}

type MlsData = Record<string, MlsItem>;

export default function Home() {
  const [mlsData, setMlsData] = useState<MlsData>({});
  const [loading, setLoading] = useState(true);
  const [showClassics, setShowClassics] = useState(true);
  const [activeTab, setActiveTab] = useState('般若');
  const [classicTexts, setClassicTexts] = useState<ClassicTextsType>({});
  const classicsRef = React.useRef<HTMLDivElement>(null);
  const mainRef = React.useRef<HTMLDivElement>(null);
  const contentRef = React.useRef<HTMLDivElement>(null);
  const wrapperRef = React.useRef<HTMLDivElement>(null);
  const [contentHeight, setContentHeight] = useState<number | 'auto'>('auto');

  // Load saved tab and visibility from localStorage on mount
  useEffect(() => {
    const savedTab = localStorage.getItem('classicTextsActiveTab');
    if (savedTab) {
      setActiveTab(savedTab);
    }

    const savedVisibility = localStorage.getItem('classicTextsVisible');
    if (savedVisibility !== null) {
      setShowClassics(savedVisibility === 'true');
    }
  }, []);

  // Save tab selection to localStorage
  const handleTabChange = (tab: string) => {
    // First, set explicit height to current height for smooth transition
    if (wrapperRef.current && contentRef.current) {
      const currentHeight = contentRef.current.scrollHeight;
      setContentHeight(currentHeight);

      // Force a reflow to ensure the height is set
      wrapperRef.current.offsetHeight;

      // Then change the tab
      setTimeout(() => {
        setActiveTab(tab);
        localStorage.setItem('classicTextsActiveTab', tab);
      }, 0);
    } else {
      setActiveTab(tab);
      localStorage.setItem('classicTextsActiveTab', tab);
    }

    if (!showClassics) {
      setShowClassics(true);
      localStorage.setItem('classicTextsVisible', 'true');
    }
  };

  // Update content height when tab changes
  useEffect(() => {
    if (contentRef.current) {
      requestAnimationFrame(() => {
        if (contentRef.current) {
          const newHeight = contentRef.current.scrollHeight;
          setContentHeight(newHeight);
        }
      });
    }
  }, [activeTab, classicTexts]);

  useEffect(() => {
    const loadData = async () => {
      try {
        const [mlsResponse, classics] = await Promise.all([
          fetch('/data/mls.json'),
          loadClassicTexts()
        ]);
        const mlsDataResult = await mlsResponse.json();
        setMlsData(mlsDataResult);
        setClassicTexts(classics);
      } catch (error) {
        console.error('Failed to load data:', error);
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

  useEffect(() => {
    const syncWidth = () => {
      if (classicsRef.current && mainRef.current) {
        const mainWidth = mainRef.current.offsetWidth;
        classicsRef.current.style.width = `${mainWidth}px`;
      }
    };

    syncWidth();
    window.addEventListener('resize', syncWidth);

    // Use a timeout to ensure DOM is fully rendered
    const timer = setTimeout(syncWidth, 100);

    return () => {
      window.removeEventListener('resize', syncWidth);
      clearTimeout(timer);
    };
  }, [loading, mlsData]);

  if (loading) {
    return (
      <>
        <Header />
        <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8">
          <div className="text-center">Loading...</div>
        </div>
      </>
    );
  }

  return (
    <>
      <Header />
      <div
        className={`flex flex-col items-center min-h-screen p-8 pb-8 gap-8`}
      >
        {/* Classic Texts Section with toggle */}
        <div ref={classicsRef} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 gap-8 items-start">
          <div className="col-span-full border border-border rounded-lg overflow-hidden bg-background shadow-md">
            {/* Header with tabs - always visible */}
            <div className="px-3 py-2 md:px-5 md:py-3 bg-muted/50 flex items-center gap-3 md:gap-4">
              <h2 className="text-base md:text-lg font-semibold text-foreground whitespace-nowrap">
                <Text>常用经典</Text>
              </h2>

              {/* Mobile: Dropdown selector */}
              <div className="flex-1 md:hidden">
                <Select value={activeTab} onValueChange={handleTabChange}>
                  <SelectTrigger className="h-8 text-sm">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {Object.keys(classicTexts).map((category) => (
                      <SelectItem key={category} value={category}>
                        <Text>{category}</Text>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Desktop: Tabs */}
              <div className="hidden md:flex flex-1 items-center gap-2 overflow-x-auto">
                {Object.keys(classicTexts).map((category) => (
                  <button
                    key={category}
                    onClick={() => handleTabChange(category)}
                    className={`px-3 py-1.5 rounded-full text-sm whitespace-nowrap transition-all ${
                      activeTab === category
                        ? 'bg-primary/20 text-primary font-medium'
                        : 'text-foreground/70 hover:bg-muted/50 hover:text-foreground'
                    }`}
                  >
                    <Text>{category}</Text>
                  </button>
                ))}
              </div>

              {/* Toggle button */}
              <button
                onClick={() => {
                  const newVisibility = !showClassics;
                  setShowClassics(newVisibility);
                  localStorage.setItem('classicTextsVisible', String(newVisibility));
                }}
                className="hover:bg-muted/50 p-1.5 rounded transition-colors flex-shrink-0"
              >
                <svg
                  className="w-4 h-4 text-foreground transition-transform duration-300"
                  style={{ transform: showClassics ? 'scaleY(-1)' : 'scaleY(1)' }}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19 9l-7 7-7-7" />
                </svg>
              </button>
            </div>

            {/* Content - collapsible */}
            <div
              ref={wrapperRef}
              className="overflow-hidden"
              style={{
                height: showClassics ? (typeof contentHeight === 'number' ? `${contentHeight}px` : 'auto') : '0',
                opacity: showClassics ? 1 : 0,
                transition: 'height 0.3s ease-in-out, opacity 0.2s ease-in-out'
              }}
            >
              <div ref={contentRef}>
                <ClassicTextsContent activeTab={activeTab} classicTexts={classicTexts} />
              </div>
            </div>
          </div>
        </div>

        {/* Divider */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 gap-8 items-start">
          <div className="col-span-full">
            <div className="border-t-2 border-border"></div>
          </div>
        </div>

        <main
          ref={mainRef}
          id="annotatable-content"
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 gap-8 items-start"
        >
          {Object.entries(mlsData).map(([key, { id, name }]) => (
                // Start of Selection
                <Link
                  key={key}
                  href={`/juans/${id}`}
                  passHref
                  className="p-4 border border-border rounded-lg shadow-md w-full max-w-md block hover:bg-primary-hover transition-colors"
                >
                  <h2 className="text-xl font-semibold text-center text-foreground"><Text>{name}</Text></h2>
                </Link>
          ))}
        </main>
        <footer className="flex gap-6 flex-wrap items-center justify-center">
          {/* Footer content */}
        </footer>
      </div>
    </>
  );
}
