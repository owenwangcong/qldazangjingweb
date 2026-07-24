'use client';

/**
 * 竖排开发/E2E 专用路由(仅 dev 构建;生产 404)。
 * WS3 交互验收(CW9)在此页驱动;正式入口(书页悬浮按钮)在 WS5 接入。
 * 用法:/dev/vertical?book=0998&mode=verticalScroll
 */
import React, { useEffect, useState } from 'react';
import { notFound, useSearchParams } from 'next/navigation';
import VerticalReaderOverlay, {
  type ReadingMode,
} from '@/app/components/vertical/VerticalReaderOverlay';
import { parseBookData, type BookData } from '@/lib/vertical/models';

export default function DevVerticalPage() {
  if (process.env.NODE_ENV === 'production') notFound();
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const params = useSearchParams();
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const [book, setBook] = useState<BookData | null>(null);
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const [exitedAt, setExitedAt] = useState<number | null>(null);

  const bookId = params.get('book') ?? '0998';
  const mode = (params.get('mode') as ReadingMode) ?? 'verticalPaged';

  // eslint-disable-next-line react-hooks/rules-of-hooks
  useEffect(() => {
    let alive = true;
    fetch(`/data/books/${bookId}.json`)
      .then((r) => r.json())
      .then((j) => {
        if (alive) setBook(parseBookData(j));
      });
    return () => {
      alive = false;
    };
  }, [bookId]);

  if (exitedAt !== null) {
    return (
      <div style={{ padding: 40 }}>
        <p data-exited={exitedAt}>已退出竖排,锚定块 {exitedAt}</p>
        <button data-reopen onClick={() => setExitedAt(null)}>
          重新打开
        </button>
      </div>
    );
  }

  if (!book) return <div style={{ padding: 40 }}>加载中…</div>;

  return (
    <VerticalReaderOverlay
      book={book}
      initialMode={mode}
      onExit={(b) => setExitedAt(b)}
    />
  );
}
