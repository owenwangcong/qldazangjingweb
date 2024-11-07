import { NextRequest, NextResponse } from 'next/server';
import * as OpenCC from 'opencc-js';
import logger from '../../utils/logger'; // Import the logger

export async function POST(request: NextRequest) {
  const userIp = request.headers.get('x-forwarded-for') || request.ip || 'Unknown IP';

  try {
    const { key } = await request.json();

    if (!key) {
      logger.log('POST /todict - Missing key', userIp); // Log error
      return NextResponse.json({ error: '请先选择文字' }, { status: 400 });
    } else {
      console.log('key', key);
      logger.log(`POST /todict - Received key: ${key}`, userIp); // Log received key
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
      logger.log(`POST /todict - External API error: ${errorText}`, userIp); // Log external API error
      throw new Error(`External API error: ${response.json}`);
    }

    const data = await response.json();
    logger.log(`POST /todict - Successfully fetched data for ${simplifiedKey}`, userIp); // Log success
    return NextResponse.json(data);
  } catch (error: any) {
    console.error('Translation API Error:', error);
    logger.log(`POST /todict - Internal Server Error: ${error.message}`, userIp); // Log internal error
    return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 });
  }
}
