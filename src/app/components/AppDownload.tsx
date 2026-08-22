"use client";

import React from 'react';
import { Smartphone, Download } from 'lucide-react';
import Text from './Text';

// App distribution constants.
// APP_VERSION tracks the version NAME published on Play, not pubspec.yaml — the
// hosted APK must be the "Signed, universal APK" pulled from Play Console so its
// signature matches what Play ships (see claudedocs/apk-hosting.md).
export const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.aeonlectron.dazangjing';
export const APP_VERSION = '1.0.0';
export const APK_URL = `/apk/qldazangjing-${APP_VERSION}.apk`;
export const APK_SIZE = '约 72 MB';

interface AppDownloadProps {
  /**
   * compact — single row for the home page footer.
   * full    — headed section with description, for the intro page.
   */
  variant?: 'compact' | 'full';
}

const buttonClass =
  'flex items-center px-4 py-2.5 rounded-xl bg-card shadow-sm border border-border/50 hover:bg-primary-hover hover:text-primary-foreground-hover hover:shadow-md transition-all duration-200';

const AppDownload: React.FC<AppDownloadProps> = ({ variant = 'compact' }) => {
  const playLink = (
    <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer" className={buttonClass}>
      <Smartphone className="w-5 h-5 mr-2" aria-hidden="true" />
      <Text>Google Play 下载</Text>
    </a>
  );

  // Sideload path for users without Google Play (notably mainland China).
  const apkLink = (
    <a href={APK_URL} download className={buttonClass}>
      <Download className="w-5 h-5 mr-2" aria-hidden="true" />
      <Text>{`下载 APK（${APK_SIZE}）`}</Text>
    </a>
  );

  if (variant === 'compact') {
    return (
      <div className="flex flex-wrap items-center justify-center gap-4 py-4">
        <p className="text-sm text-muted-foreground">
          <Text>乾隆大藏经 Android App 已上线，支持离线阅读</Text>
        </p>
        {playLink}
        {apkLink}
      </div>
    );
  }

  return (
    <>
      <h2 id="appDescription" className="w-full max-w-4xl text-2xl font-bold flex justify-center p-2 m-2 bg-secondary">
        <Text>手机 App</Text>
      </h2>
      <div className="w-full max-w-4xl">
        <Text>乾隆大藏经 Android App 已在 Google Play 上线。App 内置全部经文与阅读字体，安装后无需联网即可阅读，并支持竖排排版、繁简切换、字号与字重调节、收藏与书签。</Text>
        <div className="flex flex-wrap items-center justify-center gap-4 mt-4">
          {playLink}
          {apkLink}
        </div>
        <p className="text-sm text-muted-foreground text-center mt-4">
          <Text>{`当前版本 ${APP_VERSION}。APK 供无法访问 Google Play 的用户直接安装，安装前需在系统设置中允许“安装未知来源应用”。安装包内置全部经文与八款字体，建议在 Wi-Fi 下下载。`}</Text>
        </p>
      </div>
    </>
  );
};

export default AppDownload;
