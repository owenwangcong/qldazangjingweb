"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import Text from './Text';

interface ClassicText {
  id: string;
  title: string;
}

export type ClassicTexts = Record<string, ClassicText[]>;

let cachedClassicTexts: ClassicTexts | null = null;

export async function loadClassicTexts(): Promise<ClassicTexts> {
  if (cachedClassicTexts) {
    return cachedClassicTexts;
  }

  try {
    const response = await fetch('/data/classics.json');
    const data = await response.json();
    cachedClassicTexts = data;
    return data;
  } catch (error) {
    console.error('Failed to load classics data:', error);
    return {};
  }
}

interface ClassicTextsContentProps {
  activeTab: string;
  classicTexts: ClassicTexts;
}

export function ClassicTextsContent({ activeTab, classicTexts }: ClassicTextsContentProps) {
  const texts = classicTexts[activeTab] || [];

  return (
    <div className="w-full p-4 md:p-6 pt-3 md:pt-4">
      <div className="flex flex-wrap gap-2 md:gap-2.5">
        {texts.map((text) => (
          <Link
            key={text.id}
            href={`/books/${text.id}`}
            className="inline-block px-3 py-1.5 md:px-4 md:py-2 border border-border/50 rounded-lg bg-background/40 backdrop-blur-sm hover:bg-primary-hover hover:text-primary-foreground-hover hover:shadow-sm transition-all duration-200 text-xs md:text-sm"
          >
            <Text>{text.title}</Text>
          </Link>
        ))}
      </div>
    </div>
  );
}
