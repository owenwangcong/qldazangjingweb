import { NextApiRequest, NextApiResponse } from 'next';
import path from 'path';
import fs from 'fs';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { id } = req.query;
  const filePath = path.join(process.cwd(), 'data/books', `${id}.json`);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Book not found' });
  }

  try {
    const bookData = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    res.status(200).json(bookData);
  } catch (error) {
    res.status(500).json({ error: 'Failed to load book data' });
  }
}
