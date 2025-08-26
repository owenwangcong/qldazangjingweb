import { NextRequest, NextResponse } from 'next/server';
import logger from '../../utils/logger'; // Import the logger

export async function POST(request: NextRequest) {
  const userIp = request.headers.get('x-forwarded-for') || request.ip || 'Unknown IP';
  const userAgent = request.headers.get('user-agent') || 'Unknown';
  const method = request.method;
  const url = request.url;

  try {
    const { text, action } = await request.json();

    if (!action) {
      logger.warn('POST /tochatgpt - Missing action parameter', userIp, userAgent, method, url);
      return NextResponse.json({ error: '请先选择动作' }, { status: 400 });
    }

    if (!text) {
      logger.warn('POST /tochatgpt - Missing text parameter', userIp, userAgent, method, url);
      return NextResponse.json({ error: '请先选择文字' }, { status: 400 });
    }

    // Validate action parameter
    const validActions = ['tomodernchinese', 'explain', 'lookupdictionary'];
    if (!validActions.includes(action)) {
      logger.warn(`POST /tochatgpt - Invalid action: ${action}`, userIp, userAgent, method, url);
      return NextResponse.json({ error: '无效的操作类型' }, { status: 400 });
    }

    // Truncate text for logging (avoid logging sensitive/long content)
    const truncatedText = text.length > 100 ? text.substring(0, 100) + '...' : text;
    logger.log(`POST /tochatgpt - Processing ${action} request for text: "${truncatedText}"`, userIp, userAgent, method, url);

    let prompt = '';

    if (action === 'tomodernchinese') {
      prompt = `把下面这段文字翻译成白话文。只给我翻译后的现代白话文，不要任何其他内容：${text}`;
    } else if (action === 'explain') {
      prompt = `作为一位深谙佛教智慧且具备法师洞见的导师，请以通俗易懂的方式，深入解读以下佛经段落的含义。请详细阐述其历史背景、核心教义，并解释该教义在佛教修行中的实际作用，使人容易理解和体会：${text}`;
    } else if (action === 'lookupdictionary') {
      prompt = `你是一部佛教词典。我希望你能提供词典式的释义。请为以下词语提供简明定义：${text}`;
    }

    logger.debug('ChatGPT prompt prepared', { action, textLength: text.length }, userIp);

    const apiUrl = 'https://a5axo76waf.execute-api.ca-central-1.amazonaws.com/ToChatGPT';

    const startTime = Date.now();
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ prompt }),
    });
    const apiResponseTime = Date.now() - startTime;

    if (!response.ok) {
      const errorText = await response.text();
      const error = new Error(`External API error: ${response.status} ${response.statusText} - ${errorText}`);
      logger.error('POST /tochatgpt - External API failed', error, userIp, userAgent, method, url);
      throw error;
    }

    const data = await response.json();
    logger.log(`POST /tochatgpt - Successfully processed ${action} request (${apiResponseTime}ms)`, userIp, userAgent, method, url);
    
    // Log response size for monitoring
    const responseSize = JSON.stringify(data).length;
    logger.debug('ChatGPT API response received', { 
      responseSize, 
      apiResponseTime,
      action 
    }, userIp);
    
    return NextResponse.json(data);
  } catch (error: any) {
    logger.error('POST /tochatgpt - Request failed', error, userIp, userAgent, method, url);
    return NextResponse.json({ 
      error: error.message || 'Internal Server Error',
      timestamp: new Date().toISOString(),
      requestId: Math.random().toString(36).substring(7)
    }, { status: 500 });
  }
}
