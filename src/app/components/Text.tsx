import React from 'react';
import { useLanguage } from '../context/LanguageContext';

interface TextProps {
  children: string;
  className?: string;
}

const Text: React.FC<TextProps> = ({ children, className }) => {
  const { convertText } = useLanguage();
  const convertedText = convertText(children);

  return <span className={className}>{convertedText}</span>;
};

export default Text;
