import { Metadata } from 'next';

const SITE_URL = 'https://qldazangjing.com';
const APP_NAME_ZH = '乾隆大藏经';
const APP_NAME_EN = 'Qianlong Tripitaka (Dazangjing)';
const APP_PACKAGE = 'com.aeonlectron.dazangjing';
const LAST_UPDATED = '2026-06-20';

export async function generateMetadata(): Promise<Metadata> {
  const description =
    '乾隆大藏经 Android 应用隐私政策。本应用为离线优先的佛经阅读工具，不收集个人身份信息，不含广告与第三方追踪。Privacy Policy for the Qianlong Tripitaka Android app.';

  return {
    title: '隐私政策 | Privacy Policy',
    description,
    alternates: {
      canonical: '/privacy-policy',
    },
    openGraph: {
      title: `隐私政策 Privacy Policy | ${APP_NAME_ZH}`,
      description,
      url: `${SITE_URL}/privacy-policy`,
      type: 'website',
      siteName: APP_NAME_ZH,
    },
  };
}

export default function PrivacyPolicyPage() {
  return (
    <main className="min-h-screen bg-[#f7f3ea] text-stone-800">
      <article className="mx-auto max-w-3xl px-6 py-12 sm:py-16 leading-relaxed">
        <header className="mb-10 border-b border-stone-300 pb-6">
          <h1 className="text-3xl font-semibold tracking-tight text-stone-900">
            隐私政策 · Privacy Policy
          </h1>
          <p className="mt-3 text-stone-600">
            应用 / Application：<strong>{APP_NAME_ZH}</strong> （{APP_NAME_EN}）
          </p>
          <p className="text-stone-600">
            应用包名 / Package：<code className="rounded bg-stone-200 px-1.5 py-0.5 text-sm">{APP_PACKAGE}</code>
          </p>
          <p className="mt-1 text-sm text-stone-500">
            最近更新 / Last updated：{LAST_UPDATED}
          </p>
        </header>

        {/* ===================== 中文 ===================== */}
        <section className="space-y-6">
          <h2 className="text-xl font-semibold text-stone-900">中文</h2>

          <p>
            《{APP_NAME_ZH}》是一款离线优先的佛教经典阅读应用（以下简称“本应用”）。
            我们高度重视用户隐私。本隐私政策说明本应用如何处理信息。
            <strong>本应用不收集、不存储、也不会与任何第三方共享您的个人身份信息。</strong>
          </p>

          <div>
            <h3 className="text-lg font-medium text-stone-900">1. 我们收集的信息</h3>
            <p className="mt-2">
              本应用<strong>不会要求您注册账户，也不会收集</strong>诸如姓名、电子邮件、电话号码、
              位置、通讯录、相机或麦克风等个人信息。本应用不集成任何广告 SDK，
              也不使用第三方分析或用户行为追踪工具。
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">2. 本地存储的数据</h3>
            <p className="mt-2">
              为提供阅读功能，本应用会将以下数据<strong>仅保存在您的设备本地</strong>，
              这些数据不会上传至我们的服务器：
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-6">
              <li>阅读设置与偏好（如字体、字号、主题）；</li>
              <li>收藏、书签与学习笔记；</li>
              <li>已下载至设备以供离线阅读的经文内容。</li>
            </ul>
            <p className="mt-2">
              卸载本应用即会从您的设备中删除上述全部本地数据。
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">3. 网络访问</h3>
            <p className="mt-2">
              本应用可能通过网络从我们的内容服务器（{SITE_URL}）请求经文、辞典及相关资料，
              以便您阅读或下载离线内容。此类请求仅用于获取公开的经典文本内容，
              <strong>不包含任何可识别您个人身份的信息</strong>。
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">4. 儿童隐私</h3>
            <p className="mt-2">
              本应用内容适合所有年龄段用户，且不会收集任何用户（包括儿童）的个人信息。
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">5. 政策更新</h3>
            <p className="mt-2">
              我们可能会不时更新本隐私政策。任何更新都会发布在本页面，并更新顶部的“最近更新”日期。
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">6. 联系我们</h3>
            <p className="mt-2">
              如对本隐私政策有任何疑问，请通过电子邮件联系我们：
              <a className="text-amber-800 underline" href="mailto:wangcongowen@gmail.com">
                wangcongowen@gmail.com
              </a>
              。
            </p>
          </div>
        </section>

        <hr className="my-10 border-stone-300" />

        {/* ===================== English ===================== */}
        <section className="space-y-6">
          <h2 className="text-xl font-semibold text-stone-900">English</h2>

          <p>
            {APP_NAME_EN} (the &quot;App&quot;) is an offline-first reader for Buddhist
            scriptures. We respect your privacy. This Privacy Policy explains how the App
            handles information.{' '}
            <strong>
              The App does not collect, store, or share any personally identifiable
              information with any third party.
            </strong>
          </p>

          <div>
            <h3 className="text-lg font-medium text-stone-900">1. Information We Collect</h3>
            <p className="mt-2">
              The App does <strong>not</strong> require you to create an account and does{' '}
              <strong>not</strong> collect personal information such as your name, email,
              phone number, location, contacts, camera, or microphone. The App contains no
              advertising SDKs and uses no third-party analytics or user-tracking tools.
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">2. Data Stored Locally</h3>
            <p className="mt-2">
              To provide reading features, the App stores the following data{' '}
              <strong>only on your device</strong>. It is never uploaded to our servers:
            </p>
            <ul className="mt-2 list-disc space-y-1 pl-6">
              <li>Reading settings and preferences (e.g., font, text size, theme);</li>
              <li>Favorites, bookmarks, and study notes;</li>
              <li>Scripture content downloaded to your device for offline reading.</li>
            </ul>
            <p className="mt-2">
              Uninstalling the App removes all of this local data from your device.
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">3. Network Access</h3>
            <p className="mt-2">
              The App may request scripture texts, dictionaries, and related materials over
              the network from our content server ({SITE_URL}) so you can read or download
              content for offline use. These requests are used solely to fetch public
              scripture content and <strong>do not include any information that identifies
              you personally</strong>.
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">4. Children&apos;s Privacy</h3>
            <p className="mt-2">
              The App is suitable for users of all ages and does not collect personal
              information from any user, including children.
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">5. Changes to This Policy</h3>
            <p className="mt-2">
              We may update this Privacy Policy from time to time. Any changes will be posted
              on this page with an updated &quot;Last updated&quot; date above.
            </p>
          </div>

          <div>
            <h3 className="text-lg font-medium text-stone-900">6. Contact Us</h3>
            <p className="mt-2">
              If you have any questions about this Privacy Policy, contact us by email at{' '}
              <a className="text-amber-800 underline" href="mailto:wangcongowen@gmail.com">
                wangcongowen@gmail.com
              </a>
              .
            </p>
          </div>
        </section>

        <footer className="mt-12 border-t border-stone-300 pt-6 text-sm text-stone-500">
          © {LAST_UPDATED.slice(0, 4)} {APP_NAME_ZH} · {APP_NAME_EN}
        </footer>
      </article>
    </main>
  );
}
