import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {

    const { text, action } = await request.json();

    if (!action) {
      return NextResponse.json({ error: '请先选择动作' }, { status: 400 });
    }

    if (!text) {
      return NextResponse.json({ error: '请先选择文字' }, { status: 400 });
    }

    let prompt = '';

    if (action === 'tomodernchinese') {
      prompt = `把下面这段文字翻译成白话文。只给我翻译后的现代白话文，不要任何其他内容：${text}`;
    } else if (action === 'explain') {
      prompt = `作为一位深谙佛教智慧且具备法师洞见的导师，请以通俗易懂的方式，深入解读以下佛经段落的含义。请详细阐述其历史背景、核心教义，并解释该教义在佛教修行中的实际作用，使人容易理解和体会：${text}`;
    } else if (action === 'lookupdictionary') {
      prompt = `你是一部佛教词典。我希望你能提供词典式的释义。请为以下词语提供简明定义：${text}`;
    } else{
      return NextResponse.json({ error: '请先选择文字' }, { status: 400 });
    }

    const apiUrl = 'https://a5axo76waf.execute-api.ca-central-1.amazonaws.com/ToChatGPT';

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ prompt }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`External API error: ${errorText}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error: any) {
    console.error('Translation API Error:', error);
    return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 });
  }
}
