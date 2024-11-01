"use client";

import React, { createContext, useContext, useState, ReactNode, useEffect } from 'react';

// Define the shape of an annotation
export interface Annotation {
  id: string;
  text: string;
  bookId: string;
  body: any[];
}

// Define the shape of the context
interface AnnotationContextProps {
  annotations: Annotation[];
  addAnnotation: (annotation: Annotation, bookId: string) => void;
  removeAnnotation: (id: string, bookId: string) => void; // Update to accept id
}

const DEFAULT_ANNOTATIONS: Annotation[] = [];

// Create the context
export const AnnotationContext = createContext<AnnotationContextProps>({
  annotations: DEFAULT_ANNOTATIONS,
  addAnnotation: () => {},
  removeAnnotation: () => {},
});

// AnnotationProvider component
export const AnnotationProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [annotations, setAnnotations] = useState<Annotation[]>(() => {
    if (typeof window !== "undefined") {
      const storedAnnotations = localStorage.getItem('annotations');
      return storedAnnotations ? JSON.parse(storedAnnotations) : DEFAULT_ANNOTATIONS;
    }
    return DEFAULT_ANNOTATIONS;
  });

  // Load annotations from localStorage on mount
  useEffect(() => {
    if (typeof window !== "undefined") {
      const storedAnnotations = localStorage.getItem('annotations');
      if (storedAnnotations) {
        setAnnotations(JSON.parse(storedAnnotations));
      }
    }
  }, []);

  // Save annotations to localStorage whenever they change
  useEffect(() => { 
    if (typeof window !== "undefined") {
      localStorage.setItem('annotations', JSON.stringify(annotations));
    }
  }, [annotations]);

  const addAnnotation = (annotation: Annotation, bookId: string) => {
    setAnnotations(prev => [...prev, { ...annotation, bookId }]);
  };

  const removeAnnotation = (id: string, bookId: string) => {
    setAnnotations(prev => prev.filter(existingAnnotation => !(existingAnnotation.id === id && existingAnnotation.bookId === bookId)));
  };

  return (
    <AnnotationContext.Provider value={{ annotations, addAnnotation, removeAnnotation }}>
      {children}
    </AnnotationContext.Provider>
  );
};

// Custom hook to use the AnnotationContext
export const useAnnotations = () => useContext(AnnotationContext);
