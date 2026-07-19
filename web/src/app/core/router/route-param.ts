import { ActivatedRoute } from '@angular/router';

/** Walk the activated route tree for a path param (needed under adaptive modal hosts). */
export function routeParam(route: ActivatedRoute, key: string): string | null {
  let current: ActivatedRoute | null = route;
  while (current) {
    const value = current.snapshot.paramMap.get(key);
    if (value) {
      return value;
    }
    current = current.parent;
  }
  return null;
}
