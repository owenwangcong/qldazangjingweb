"use client";

import React, { useEffect, useRef } from 'react';
import { useLanguage } from '../context/LanguageContext';

interface IntroTourProps {
  enabled: boolean;
  onExit: () => void;
}

const IntroTour: React.FC<IntroTourProps> = ({ enabled, onExit }) => {
  // Early return if not in browser
  if (typeof window === 'undefined') {
    return null;
  }

  const { isSimplified } = useLanguage();
  const introRef = useRef<any>(null);
  const hasStartedRef = useRef(false);

  const getAllSteps = () => {
    return [
      {
        intro: isSimplified
          ? '欢迎来到乾隆大藏经 - 让我们快速了解一下这个网站的功能'
          : '歡迎來到乾隆大藏經 - 讓我們快速了解一下這個網站的功能',
      },
      {
        element: '#header',
        intro: isSimplified
          ? '<h4>控制界面</h4><p>右上角的按钮提供了各种阅读和自定义功能。让我们逐一了解它们。</p>'
          : '<h4>控制界面</h4><p>右上角的按鈕提供了各種閱讀和自定義功能。讓我們逐一了解它們。</p>',
        position: 'bottom',
      },
      {
        element: '[data-tour="toggle-visibility"]',
        intro: isSimplified
          ? '<h4>隐藏/显示界面</h4><p>点击此按钮可以隐藏或显示所有控制按钮，让您专注于阅读。</p>'
          : '<h4>隱藏/顯示界面</h4><p>點擊此按鈕可以隱藏或顯示所有控制按鈕，讓您專注於閱讀。</p>',
        position: 'left',
      },
      {
        element: '[data-tour="theme-selector"]',
        intro: isSimplified
          ? '<h4>主题选择</h4><p>点击\"色\"按钮可以选择6种精美的颜色主题。</p>'
          : '<h4>主題選擇</h4><p>點擊\"色\"按鈕可以選擇6種精美的顏色主題。</p>',
        position: 'left',
      },
      {
        element: '[data-tour="language-toggle"]',
        intro: isSimplified
          ? '<h4>简繁切换</h4><p>点击此按钮可以在简体中文和繁体中文之间切换。</p>'
          : '<h4>簡繁切換</h4><p>點擊此按鈕可以在簡體中文和繁體中文之間切換。</p>',
        position: 'left',
      },
      {
        element: '[data-tour="font-settings"]',
        intro: isSimplified
          ? '<h4>字体设置</h4><p>点击\"字\"按钮可以自定义阅读体验。</p>'
          : '<h4>字體設置</h4><p>點擊\"字\"按鈕可以自定義閱讀體驗。</p>',
        position: 'left',
      },
      {
        element: '[data-tour="table-of-contents"]',
        intro: isSimplified
          ? '<h4>目录导航</h4><p>点击\"目\"按钮可以查看书籍的目录。</p>'
          : '<h4>目錄導航</h4><p>點擊\"目\"按鈕可以查看書籍的目錄。</p>',
        position: 'left',
      },
      {
        element: '[data-tour="favorites"]',
        intro: isSimplified
          ? '<h4>收藏书籍</h4><p>点击\"藏\"按钮可以将当前书籍添加到收藏列表。</p>'
          : '<h4>收藏書籍</h4><p>點擊\"藏\"按鈕可以將當前書籍添加到收藏列表。</p>',
        position: 'left',
      },
      {
        element: '[data-tour="bookmarks"]',
        intro: isSimplified
          ? '<h4>添加书签</h4><p>点击\"签\"按钮可以为当前阅读位置添加书签。</p>'
          : '<h4>添加書籤</h4><p>點擊\"簽\"按鈕可以為當前閱讀位置添加書籤。</p>',
        position: 'left',
      },
      {
        element: '[data-tour="download"]',
        intro: isSimplified
          ? '<h4>下载PDF</h4><p>点击\"存\"按钮可以将当前书籍保存为PDF文档。</p>'
          : '<h4>下載PDF</h4><p>點擊\"存\"按鈕可以將當前書籍保存為PDF文檔。</p>',
        position: 'left',
      },
      {
        intro: isSimplified
          ? '<h4>阅读体验</h4><p>这是主要的经文阅读区域。您可以选中文字后右键点击，使用复制、搜索、字典、AI翻译、AI释义、添加注释等功能。页面底部还提供了上一部和下一部经书的导航链接。</p>'
          : '<h4>閱讀體驗</h4><p>這是主要的經文閱讀區域。您可以選中文字後右鍵點擊，使用複製、搜索、字典、AI翻譯、AI釋義、添加註釋等功能。頁面底部還提供了上一部和下一部經書的導航鏈接。</p>',
      },
      {
        intro: isSimplified
          ? '<h3>开始您的阅读之旅</h3><p>现在您已经了解了所有功能！祝您阅读愉快。</p>'
          : '<h3>開始您的閱讀之旅</h3><p>現在您已經了解了所有功能！祝您閱讀愉快。</p>',
      },
    ];
  };

  useEffect(() => {
    if (!enabled || hasStartedRef.current) {
      return;
    }

    hasStartedRef.current = true;

    const timer = setTimeout(async () => {
      try {
        // Dynamically import intro.js and CSS only on client-side
        const introJsModule = await import('intro.js');
        await import('intro.js/introjs.css');
        await import('../styles/intro-custom.css');

        const introJs = introJsModule.default || introJsModule;
        const allSteps = getAllSteps();

        // Filter valid steps
        const validSteps = allSteps.filter(step => {
          // Always include steps without an element (general intro steps)
          if (!step.element) return true;
          // For steps with elements, check if element exists
          return document.querySelector(step.element) !== null;
        });

        console.log('Valid steps:', validSteps.length, 'out of', allSteps.length);

        if (validSteps.length === 0) {
          console.error('No valid intro steps found');
          hasStartedRef.current = false;
          return;
        }

        // Create intro instance
        const intro = introJs();
        introRef.current = intro;

        // Set options using setOptions method
        intro.setOptions({
          steps: validSteps,
          nextLabel: isSimplified ? '下一步' : '下一步',
          prevLabel: isSimplified ? '上一步' : '上一步',
          skipLabel: isSimplified ? '跳过' : '跳過',
          doneLabel: isSimplified ? '完成' : '完成',
          showProgress: true,
          showBullets: false,
          exitOnOverlayClick: false,
          exitOnEsc: true,
          scrollToElement: true,
          scrollPadding: 30,
          overlayOpacity: 0.8,
          // Best practices from official docs
          tooltipPosition: 'auto',
          positionPrecedence: ['left', 'right', 'bottom', 'top'],
        });

        // Set up callbacks
        intro.onexit(function() {
          console.log('Tour exited');
          // Clean up any text selection and context menu
          window.getSelection()?.removeAllRanges();
          // Try to close any open context menu by pressing Escape
          document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
          onExit();
        });

        intro.oncomplete(function() {
          console.log('Tour completed');
        });

        intro.onbeforechange(function(targetElement) {
          console.log('Before change to element:', targetElement);
          return true;
        });

        intro.onchange(function(targetElement) {
          console.log('Changed to element:', targetElement);
          // Re-bind double-click prevention on step change
          setTimeout(() => {
            const tooltip = document.querySelector('.introjs-tooltip');
            if (tooltip) {
              tooltip.addEventListener('dblclick', (e) => {
                e.stopPropagation();
                e.preventDefault();
                console.log('Double-click on tooltip prevented');
              }, true);
            }
          }, 50);
        });

        console.log('Starting intro tour with', validSteps.length, 'steps');
        // Start the tour
        try {
          intro.start();
          console.log('Tour started successfully');

          // Prevent double-click on tooltip from exiting the tour
          setTimeout(() => {
            const tooltip = document.querySelector('.introjs-tooltip');
            if (tooltip) {
              tooltip.addEventListener('dblclick', (e) => {
                e.stopPropagation();
                e.preventDefault();
                console.log('Double-click on tooltip prevented');
              }, true);
            }
          }, 100);
        } catch (startError) {
          console.error('Error during intro.start():', startError);
          hasStartedRef.current = false;
        }
      } catch (error) {
        console.error('Error starting intro tour:', error);
        hasStartedRef.current = false;
      }
    }, 800);

    return () => {
      clearTimeout(timer);
      if (introRef.current) {
        try {
          introRef.current.exit(false);
        } catch (e) {
          // Ignore
        }
      }
    };
  }, [enabled, isSimplified, onExit]);

  return null;
};

export default IntroTour;
