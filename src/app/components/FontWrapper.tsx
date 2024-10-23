'use client';

import React, { useContext } from 'react';
import { FontContext } from '../context/FontContext';

const FontWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { selectedFont } = useContext(FontContext);

  return (
    <div style={{ fontFamily: `var(${selectedFont})` }}>
      {children}
    </div>
  );
};

export default FontWrapper;
