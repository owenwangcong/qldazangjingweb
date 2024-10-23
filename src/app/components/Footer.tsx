import React from 'react';
import Text from './Text';

const Footer: React.FC = () => {
  return (
    <footer className="w-full p-4 bg-gray-800 text-white">
      <div className="container mx-auto text-center">
        <p><Text>版权所有 © 2023 乾隆大藏经</Text></p>
      </div>
    </footer>
  );
};

export default Footer;
