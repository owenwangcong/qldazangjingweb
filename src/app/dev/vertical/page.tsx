/**
 * 竖排开发/E2E 路由的服务端守卫:生产构建返回真 404(W9;
 * 客户端 notFound() 只换 UI 不改状态码,守卫必须在服务端做——实施备忘 WS6)。
 */
import { notFound } from 'next/navigation';
import DevVerticalClient from './DevVerticalClient';

export const dynamic = 'force-dynamic';

export default function Page() {
  if (process.env.NODE_ENV === 'production') notFound();
  return <DevVerticalClient />;
}
