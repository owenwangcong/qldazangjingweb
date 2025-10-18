'use client';

import { useEffect } from 'react';
import { FontProvider } from './context/FontContext';
import { LanguageProvider } from './context/LanguageContext';
import { ThemeProvider } from './context/ThemeContext';
import { MyStudyProvider } from './context/MyStudyContext';
import { AnnotationProvider } from './context/AnnotationContext';
import FontWrapper from './components/FontWrapper';
import { Toaster } from '@/components/ui/toaster';
import Script from 'next/script';
import { usePathname } from 'next/navigation';
import ChunkErrorHandler from './components/ChunkErrorHandler';

const GA_TRACKING_ID = 'G-YYK959RPCX';

const ClientProviders = ({ children }: { children: React.ReactNode }) => {
  
  const pathname = usePathname();
  useEffect(() => {
    const handleRouteChange = (url: string) => {
      (window as any).gtag('config', GA_TRACKING_ID, {
        page_path: url,
      });
    };
    handleRouteChange(pathname);
  }, [pathname]);

  useEffect(() => {
    const handleContextMenu = (event: MouseEvent) => {
      event.preventDefault();
    };
    document.addEventListener('contextmenu', handleContextMenu);
    return () => {
      document.removeEventListener('contextmenu', handleContextMenu);
    };
  }, []);

  return (
    <>
      <Script src="/scripts/opencc.min.js" strategy="beforeInteractive" />
      <ChunkErrorHandler />
      <AnnotationProvider>
        <MyStudyProvider>
          <FontProvider>
            <LanguageProvider>
              <ThemeProvider>
                <FontWrapper>
                  {children}
                </FontWrapper>
              </ThemeProvider>
            </LanguageProvider>
          </FontProvider>
        </MyStudyProvider>
      </AnnotationProvider>
      <Toaster />
    </>
  );
};

export default ClientProviders; 