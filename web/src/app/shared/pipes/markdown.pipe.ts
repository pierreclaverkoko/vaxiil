import { Pipe, PipeTransform, inject } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { parse } from 'marked';

@Pipe({
  name: 'markdown',
  standalone: true,
})
export class MarkdownPipe implements PipeTransform {
  private readonly sanitizer = inject(DomSanitizer);

  transform(content: string | null | undefined): SafeHtml {
    if (!content) {
      return '';
    }
    const html = parse(content) as string;
    return this.sanitizer.bypassSecurityTrustHtml(html);
  }
}
