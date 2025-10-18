"use client";

import React, { useState, useEffect } from 'react';
import { Search as SearchIcon } from 'lucide-react';
import classNames from 'classnames';
import Text from '@/app/components/Text';
import Header from '@/app/components/Header';
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from '@radix-ui/react-dropdown-menu';
import { Button } from '@/components/ui/button';
import { useTheme } from '@/app/context/ThemeContext';

const IntroPageClient: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [results, setResults] = useState<any[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // Handle search input changes
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const term = e.target.value;
    setSearchTerm(term);
  };

  // Handle search button click
  const handleSearch = () => {
    const trimmedTerm = searchTerm.trim();
    if (trimmedTerm === '') {
      setResults([]);
      return;
    }
    fetchResults(trimmedTerm);
  };

  // Fetch results from dictionary API
  const fetchResults = async (term: string) => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch('/api/todict/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ key: term }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Network response was not ok');
      }

      const data = await response.json();
      setResults(data.results || []);
    } catch (err: any) {
      setError(err.message || 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <Header />
        <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8 text-lg">
        <h1 className="text-3xl"><Text>乾隆大藏经网站简介</Text></h1>

        <div className="w-full max-w-4xl">
            <Text>欢迎来到乾隆大藏经网站。本网站致力于为您提供便捷、现代化的乾隆大藏经阅读体验。我们提供了多种功能来帮助您更好地阅读和研究经文，包括文本显示控制、繁简转换、注释功能等。以下将为您详细介绍网站的主要功能和使用方法。</Text>
        </div>

        <h2 id="controlButtonDescription" className="w-full max-w-4xl text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>控制界面</Text></h2>
        <div className="w-full max-w-4xl">
            <Text>在网站的右上角，有一组控制按钮，可以帮助您调整阅读体验。您可以通过这些按钮来隐藏/显示控制界面、更换颜色主题、切换繁简中文、更换字体、显示目录等。</Text>
        </div>
        <div className="flex flex-col gap-2">
            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">隐</div></button>
                <div className="flex flex-col justify-center">
                    <Text>隐藏控制界面</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">显</div></button>
                <div className="flex flex-col justify-center">
                    <Text>显示控制界面</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">色</div></button>
                <div className="flex flex-col justify-center">
                    <Text>更换网站颜色主题</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">繁</div></button>
                <div className="flex flex-col justify-center">
                    <Text>切换至繁体中文</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">简</div></button>
                <div className="flex flex-col justify-center">
                    <Text>切换至简体中文</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">字</div></button>
                <div className="flex flex-col justify-center">
                    <Text>更换网站字体</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">目</div></button>
                <div className="flex flex-col justify-center">
                    <Text>显示书籍目录</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">藏</div></button>
                <div className="flex flex-col justify-center">
                    <Text>添加书籍至收藏</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">签</div></button>
                <div className="flex flex-col justify-center">
                    <Text>添加当前阅读位置至书签</Text>
                </div>
            </div>

            <div className="flex flex-row gap-2">
                <button className="p-2 bg-card rounded-full shadow-md"><div className="w-5 h-5 flex items-center justify-center">存</div></button>
                <div className="flex flex-col justify-center">
                    <Text>将此经文下载保存为PDF文档</Text>
                </div>
            </div>

        </div>

        <h2 id="contextMenuDescription" className="w-full max-w-4xl text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>弹出按钮</Text></h2>
        <div className="w-full max-w-4xl">
            <Text>在阅读过程中，选中文字后点击鼠标右键，会弹出以下按钮，可以对选中的文字进行不同的操作。</Text>
        </div>
        <div className="flex flex-col gap-2">
            <div className="flex flex-row gap-2 pb-1">
                <Button className="bg-muted/90 backdrop-blur-sm shadow-md"><Text>复制</Text></Button>
                <div className="flex flex-col justify-center"><Text>复制选中的经文</Text></div>
            </div>
            <div className="flex flex-row gap-2 pb-1">
                <Button className="bg-muted/90 backdrop-blur-sm shadow-md"><Text>搜索</Text></Button>
                <div className="flex flex-col justify-center"><Text>在搜索引擎中搜索</Text></div>
            </div>
            <div className="flex flex-row gap-2 pb-1">
                <Button className="bg-muted/90 backdrop-blur-sm shadow-md"><Text>字典</Text></Button>
                <div className="flex flex-col justify-center"><Text>在佛学辞典中查询选中的经文</Text></div>
            </div>
            <div className="flex flex-row gap-2 pb-1">
                <Button className="bg-muted/90 backdrop-blur-sm shadow-md"><Text>今译</Text></Button>
                <div className="flex flex-col justify-center"><Text>把选中的经文翻译成现代汉语</Text></div>
            </div>
            <div className="flex flex-row gap-2 pb-1">
                <Button className="bg-muted/90 backdrop-blur-sm shadow-md"><Text>释义</Text></Button>
                <div className="flex flex-col justify-center"><Text>解释选中经文的佛教义理</Text></div>
            </div>
            <div className="flex flex-row gap-2 pb-1">
                <Button className="bg-muted/90 backdrop-blur-sm shadow-md"><Text>注释</Text></Button>
                <div className="flex flex-col justify-center"><Text>注释选中的经文</Text></div>
            </div>
        </div>

        <h2 id="contextMenuDescription" className="w-full max-w-4xl text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>搜索</Text></h2>
        <div className="w-full max-w-4xl">
            <Text>在搜索页面中，您可以使用两种搜索模式来查找经书：</Text>
        </div>
        <div className="w-full max-w-4xl">
            <h3 className="text-xl font-semibold mb-2"><Text>全文搜索</Text></h3>
            <Text>在整个大藏经的内容中搜索关键词或短语。搜索结果会显示匹配的经书，并高亮显示匹配的内容片段。全文搜索还支持以下功能：</Text>
            <ul className="list-disc list-inside ml-4 mt-2 space-y-1">
                <li><Text>智能匹配：系统会自动处理繁简转换，智能匹配相关内容</Text></li>
                <li><Text>精确短语匹配：勾选此选项后，只会显示完全匹配搜索词的结果</Text></li>
                <li><Text>匹配度评分：每个搜索结果会显示匹配度分数，帮助您找到最相关的内容</Text></li>
                <li><Text>内容预览：搜索结果会显示匹配的内容片段，并高亮显示关键词</Text></li>
            </ul>
        </div>
        <div className="w-full max-w-4xl mt-4">
            <h3 className="text-xl font-semibold mb-2"><Text>标题搜索</Text></h3>
            <Text>在经书的标题和作者中搜索关键词。适合您知道经书名称或作者，需要快速定位特定经书的情况。</Text>
        </div>
        <div className="w-full max-w-4xl mt-4">
            <Text>输入关键词后点击搜索按钮或按回车键即可搜索。搜索结果支持分页浏览，点击任意一条搜索结果即可进入该经书的阅读页面。</Text>
        </div>

        <h2 id="contextMenuDescription" className="w-full max-w-4xl text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>辞典</Text></h2>
        <div className="w-full max-w-4xl">
            <Text>在辞典页面中，您可以查询佛教术语的含义。输入要查询的词后点击查询按钮或按回车键即可查询。查询结果会显示该词在不同佛教辞典中的解释。</Text>
        </div>

            <h2 id="contextMenuDescription" className="w-full max-w-4xl text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>我的书房</Text></h2>
        <div className="w-full max-w-4xl">
            <Text>在我的书房页面中，您可以查看您的收藏、阅读历史、书签和注释。点击任意一条记录即可进入相应的经书阅读页面。您也可以删除不需要的记录。</Text>
        </div>

        <h2 id="authorDescription" className="w-full max-w-4xl text-2xl font-bold flex justify-center p-2 m-2 bg-secondary"><Text>其他</Text></h2>
        <div className="w-full max-w-4xl">
            <Text>如有问题或建议，请发送邮件至 owen_wangcong@hotmail.com 或添加微信 wangcongowen</Text>
            <div className="flex justify-center mt-4">
            <Text>扫码添加微信</Text>
            </div>
            <div className="flex justify-center mt-4">
                <img
                    src="/images/wechat_qr.png"
                    alt="WeChat QR Code"
                    className="w-48 h-48 rounded-lg shadow-md"
                />
            </div>
        </div>

      </div>
    </div>
  );
};

export default IntroPageClient;
