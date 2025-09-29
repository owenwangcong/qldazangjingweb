import { NextRequest, NextResponse } from 'next/server';
import OpenCC from 'opencc-js';

// Initialize converter
const converter = OpenCC.Converter({ from: 't', to: 's' });

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { text } = body;

    if (!text) {
      return NextResponse.json(
        { error: 'Text is required' },
        { status: 400 }
      );
    }

    // Convert traditional to simplified
    const simplified = converter(text);

    return NextResponse.json({
      original: text,
      simplified: simplified
    });

  } catch (error) {
    console.error('Conversion error:', error);
    return NextResponse.json(
      { error: 'Conversion failed', message: error.message },
      { status: 500 }
    );
  }
}