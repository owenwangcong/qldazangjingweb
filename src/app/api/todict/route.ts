import { NextRequest, NextResponse } from 'next/server';
import * as OpenCC from 'opencc-js';
import logger from '../../utils/logger'; // Import the logger

export async function POST(request: NextRequest) {
  const userIp = request.headers.get('x-forwarded-for') || request.ip || 'Unknown IP';
  const userAgent = request.headers.get('user-agent') || 'Unknown';
  const method = request.method;
  const url = request.url;

  try {
    const { key } = await request.json();

    if (!key) {
      logger.warn('POST /todict - Missing key parameter', userIp, userAgent, method, url);
      return NextResponse.json({ error: '请先选择文字' }, { status: 400 });
    }

    logger.log(`POST /todict - Processing key: ${key.substring(0, 50)}${key.length > 50 ? '...' : ''}`, userIp, userAgent, method, url);

    // Dynamically import OpenCC using require
    const converter = OpenCC.Converter({ from: 'tw', to: 'cn' });
    const simplifiedKey = converter(key);

    logger.debug('OpenCC conversion completed', { original: key, simplified: simplifiedKey }, userIp);

    const apiUrl = 'https://yn7n97jj9c.execute-api.ca-central-1.amazonaws.com/ToDict';

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ "key": simplifiedKey })
    });

    if (!response.ok) {
      const errorText = await response.text();
      const error = new Error(`External API error: ${response.status} ${response.statusText} - ${errorText}`);
      logger.error('POST /todict - External API failed', error, userIp, userAgent, method, url);
      throw error;
    }

    const data = await response.json();
    logger.log(`POST /todict - Successfully processed request for key: ${simplifiedKey.substring(0, 30)}${simplifiedKey.length > 30 ? '...' : ''}`, userIp, userAgent, method, url);
    return NextResponse.json(data);
  } catch (error: any) {
    logger.error('POST /todict - Request failed', error, userIp, userAgent, method, url);
    return NextResponse.json({ 
      error: error.message || 'Internal Server Error',
      timestamp: new Date().toISOString(),
      requestId: Math.random().toString(36).substring(7)
    }, { status: 500 });
  }
}
