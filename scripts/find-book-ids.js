const fs = require('fs');
const path = require('path');

const bookMetaData = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../public/data/bookMetaData.json'), 'utf8')
);

const searches = [
  '唯识三十颂',
  '唯识二十颂',
  '唯识三十论颂',
  '唯识二十论',
  '解深密经',
  '楞伽',
  '入楞伽经',
  '大势至',
  '普贤.*行愿品',
  '临济录',
  '碧岩录',
  '无门关',
  '传心法要',
  '信心铭',
  '证道歌',
  '坛经'
];

searches.forEach(search => {
  console.log(`\n=== ${search} ===`);
  const regex = new RegExp(search, 'i');
  Object.entries(bookMetaData)
    .filter(([id, book]) => regex.test(book.title) && !book.title.includes('目录'))
    .slice(0, 3)
    .forEach(([id, book]) => {
      console.log(`${id}: ${book.title}`);
    });
});
