export interface Result {
  value: string;
  dict: string;
  id: string;
  key: string;
}

export const convertResultsToMarkdown = (results: Result[]): string => {
  if (!results || results.length === 0) return '';

  return results.map(result => {
    const { key, dict, value } = result;
    return `### ${key} - *${dict}*\n\n${value}\n\n --- \n\n`;
  }).join('\n');
}; 