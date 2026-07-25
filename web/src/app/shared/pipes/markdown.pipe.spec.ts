import { TestBed } from '@angular/core/testing';
import { DomSanitizer } from '@angular/platform-browser';

import { MarkdownPipe } from './markdown.pipe';

describe('MarkdownPipe', () => {
  let pipe: MarkdownPipe;
  let sanitizer: DomSanitizer;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [MarkdownPipe],
    });
    pipe = TestBed.inject(MarkdownPipe);
    sanitizer = TestBed.inject(DomSanitizer);
  });

  it('returns empty string for nullish or empty input', () => {
    expect(pipe.transform(null)).toBe('');
    expect(pipe.transform(undefined)).toBe('');
    expect(pipe.transform('')).toBe('');
  });

  it('renders headings and lists as HTML', () => {
    const result = pipe.transform('# Hello\n\n- a\n- b');
    const html = sanitizer.sanitize(1, result) ?? '';
    expect(html).toContain('<h1>');
    expect(html).toContain('Hello');
    expect(html).toContain('<ul>');
    expect(html).toContain('<li>');
  });
});
