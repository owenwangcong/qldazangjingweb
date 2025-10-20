declare module 'intro.js' {
  export default function introJs(): IntroJs;
  export interface IntroJs {
    setOptions(options: any): IntroJs;
    start(): IntroJs;
    exit(force?: boolean): void;
    onexit(callback: () => void): IntroJs;
    oncomplete(callback: () => void): IntroJs;
    onbeforechange(callback: (targetElement: any) => boolean | void): IntroJs;
    onchange(callback: (targetElement: any) => void): IntroJs;
  }
}

declare module 'intro.js/introjs.css' {
  const content: string;
  export default content;
}

declare module 'intro.js-react';
