#!/usr/bin/env node

import assert from 'node:assert/strict';
import { retryAfterDelay } from '../../scripts/retry-after.mjs';

const fallback = 500;
const now = Date.parse('2026-09-02T00:00:00Z');

assert.equal(retryAfterDelay(null, fallback, now), fallback);
assert.equal(retryAfterDelay(undefined, fallback, now), fallback);
assert.equal(retryAfterDelay('', fallback, now), fallback);
assert.equal(retryAfterDelay('not-a-delay', fallback, now), fallback);
assert.equal(retryAfterDelay('0', fallback, now), 0);
assert.equal(retryAfterDelay('2', fallback, now), 2000);
assert.equal(retryAfterDelay('Wed, 02 Sep 2026 00:00:03 GMT', fallback, now), 3000);
assert.equal(retryAfterDelay('Tue, 01 Sep 2026 23:59:59 GMT', fallback, now), 0);
assert.throws(() => retryAfterDelay(null, -1, now), /non-negative/);
