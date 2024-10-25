declare module '@/app/scripts/recogito.min.js' {
  export interface RecogitoOptions {
    content: HTMLElement;
    mode: 'html';
    locale?: string;
    readOnly?: boolean;
  }

  export class Recogito {
    constructor(options: RecogitoOptions);

    addAnnotation(annotation: any): void;
    removeAnnotation(annotationId: string): void;
    disableSelect(): void;
    destroy(): void;
  }

  // If there are other exports, declare them here
  export interface Annotation {
    id: string;
    target: {
      selector: {
        type: string;
        start: number;
        end: number;
      };
      source: string;
    };
    body: Array<{
      type: string;
      value: string;
      purpose: string;
    }>;
  }
}
