const fs = require('fs');
const path = require('path');
const { format } = require('date-fns');

const generateSitemapIndex = () => {
  return `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://qldazangjing.com/sitemap-main.xml</loc>
  </sitemap>
  <sitemap>
    <loc>https://qldazangjing.com/sitemap-juans.xml</loc>
  </sitemap>
  <sitemap>
    <loc>https://qldazangjing.com/sitemap-books.xml</loc>
  </sitemap>
</sitemapindex>`;
};

const currentDate = format(new Date(), "yyyy-MM-dd");

const generateMainSitemap = (data) => {
  let urls = `
    <url>
        <loc>https://qldazangjing.com/</loc>
        <lastmod>${currentDate}</lastmod>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
    </url>

    <url>
        <loc>https://qldazangjing.com/intro</loc>
        <lastmod>${currentDate}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.9</priority>
    </url>

    <url>
        <loc>https://qldazangjing.com/search</loc>
        <lastmod>${currentDate}</lastmod>
        <changefreq>weekly</changefreq>
        <priority>0.9</priority>
    </url>

    <url>
        <loc>https://qldazangjing.com/dicts</loc>
        <lastmod>${currentDate}</lastmod>
        <changefreq>weekly</changefreq>
        <priority>0.8</priority>
    </url>
  `;

  return `<?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    ${urls}
    </urlset>`;
};

const generateJuansSitemap = (data) => {
  let urls = '';

  const firstLevelChildren = Object.keys(data);
  firstLevelChildren.forEach((key) => {
    urls += `
        <url>
          <loc>https://qldazangjing.com/juans/${key.replace('.htm', '').replace('ml', '')}</loc>
          <lastmod>${currentDate}</lastmod>
          <changefreq>monthly</changefreq>
          <priority>0.8</priority>
        </url>`;
  });

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${urls}
</urlset>`;
};

const generateBooksSitemap = (data) => {
  let urls = '';
  for (const [fileName, content] of Object.entries(data)) {
    content.bus.forEach((item) => {
        urls += `
        <url>
          <loc>https://qldazangjing.com/books/${item.id}</loc>
          <lastmod>${currentDate}</lastmod>
          <changefreq>monthly</changefreq>
          <priority>0.8</priority>
        </url>`;
    });
  }

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${urls}
</urlset>`;
};

const generateStaticSitemaps = () => {
  const filePath = path.join(process.cwd(), 'public', 'data', 'mls.json');
  const fileContents = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(fileContents);

  const sitemapIndex = generateSitemapIndex();
  const mainSitemap = generateMainSitemap(data);
  const juansSitemap = generateJuansSitemap(data);
  const booksSitemap = generateBooksSitemap(data);

  fs.writeFileSync(path.join(process.cwd(), 'public', 'sitemap.xml'), sitemapIndex, 'utf8');
  fs.writeFileSync(path.join(process.cwd(), 'public', 'sitemap-main.xml'), mainSitemap, 'utf8');
  fs.writeFileSync(path.join(process.cwd(), 'public', 'sitemap-juans.xml'), juansSitemap, 'utf8');
  fs.writeFileSync(path.join(process.cwd(), 'public', 'sitemap-books.xml'), booksSitemap, 'utf8');
};

generateStaticSitemaps(); 