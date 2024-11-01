import { NextRequest, NextResponse } from 'next/server';
import * as OpenCC from 'opencc-js';

export async function POST(request: NextRequest) {
  try {
    const { key } = await request.json();

    if (!key) {
      return NextResponse.json({ error: '请先选择文字' }, { status: 400 });
    } else {
      console.log('key', key);
    }

    // Dynamically import OpenCC using require
    const converter = OpenCC.Converter({ from: 'tw', to: 'cn' });
    const simplifiedKey = converter(key);

    const apiUrl = 'https://yn7n97jj9c.execute-api.ca-central-1.amazonaws.com/ToDict';

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ "key": simplifiedKey })
    });

    if (!response.ok) {
      console.log('response', response);
      const errorText = await response.text();
      throw new Error(`External API error: ${response.json}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error: any) {
    console.error('Translation API Error:', error);
    return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 });
  }
}
