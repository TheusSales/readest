import { afterEach, describe, expect, it, vi } from 'vitest';
import { getStoragePlanData, getTranslationQuota } from '@/utils/access';

const b64 = (o: object) => btoa(JSON.stringify(o)).replace(/=+$/, '');
const freeToken = `${b64({ alg: 'HS256' })}.${b64({ plan: 'free' })}.sig`;

describe('fixed quotas baked into a self-hosted app build', () => {
  afterEach(() => vi.unstubAllEnvs());

  it('honors NEXT_PUBLIC_STORAGE_FIXED_QUOTA', () => {
    vi.stubEnv('NEXT_PUBLIC_STORAGE_FIXED_QUOTA', '10737418240');
    expect(getStoragePlanData(freeToken).quota).toBe(10737418240);
  });

  it('honors NEXT_PUBLIC_TRANSLATION_FIXED_QUOTA', () => {
    vi.stubEnv('NEXT_PUBLIC_TRANSLATION_FIXED_QUOTA', '50000');
    expect(getTranslationQuota('free')).toBe(50000);
  });
});
