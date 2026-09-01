#!/usr/bin/env node

import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const siteRoot = join(root, 'docs');
const canonicalUrl = 'https://ducksss.github.io/codex-profiles/';

const read = (relativePath) => readFileSync(join(root, relativePath), 'utf8');

const fileExists = (relativePath) => {
  try {
    return statSync(join(root, relativePath)).isFile();
  } catch {
    return false;
  }
};

const assertContains = (haystack, needle, label) => {
  assert.ok(haystack.includes(needle), `${label} should contain ${needle}`);
};

const html = read('docs/index.html');
const robots = read('docs/robots.txt');
const sitemap = read('docs/sitemap.xml');
const llms = read('docs/llms.txt');
const audit = read('docs/geo-audit.md');
const measurement = read('docs/geo-measurement.md');
const pagesWorkflow = read('.github/workflows/pages.yml');
const packageJson = JSON.parse(read('package.json'));

assert.ok(statSync(siteRoot).isDirectory(), 'docs site root should exist');
assert.ok(fileExists('docs/index.html'), 'docs/index.html should exist');
assert.ok(fileExists('docs/robots.txt'), 'docs/robots.txt should exist');
assert.ok(fileExists('docs/sitemap.xml'), 'docs/sitemap.xml should exist');
assert.ok(fileExists('docs/llms.txt'), 'docs/llms.txt should exist');
assert.ok(fileExists('docs/geo-audit.md'), 'docs/geo-audit.md should exist');
assert.ok(fileExists('docs/geo-measurement.md'), 'docs/geo-measurement.md should exist');
assert.ok(fileExists('docs/.nojekyll'), 'docs/.nojekyll should exist');
assert.ok(fileExists('.github/workflows/pages.yml'), 'Pages deploy workflow should exist');

assertContains(
  html,
  `<link rel="canonical" href="${canonicalUrl}">`,
  'homepage canonical'
);
assertContains(
  html,
  '<meta name="robots" content="index,follow,max-snippet:-1,max-image-preview:large,max-video-preview:-1">',
  'homepage robots meta'
);
assert.doesNotMatch(html, /\bnoindex\b/i, 'homepage must not block indexing');
assert.doesNotMatch(html, /max-snippet\s*:\s*0/i, 'homepage must not block snippets');

const jsonLdMatch = html.match(
  /<script type="application\/ld\+json">([\s\S]*?)<\/script>/
);
assert.ok(jsonLdMatch, 'homepage should include JSON-LD');
const jsonLd = JSON.parse(jsonLdMatch[1]);
assert.equal(jsonLd['@context'], 'https://schema.org');
assert.ok(Array.isArray(jsonLd['@graph']), 'JSON-LD should use @graph');

const graphByType = new Map();
for (const node of jsonLd['@graph']) {
  const types = Array.isArray(node['@type']) ? node['@type'] : [node['@type']];
  for (const type of types) {
    if (!graphByType.has(type)) {
      graphByType.set(type, []);
    }
    graphByType.get(type).push(node);
  }
}

for (const type of [
  'Organization',
  'SoftwareApplication',
  'WebSite',
  'WebPage',
  'FAQPage',
  'BreadcrumbList',
]) {
  assert.ok(graphByType.has(type), `JSON-LD should include ${type}`);
}

const app = graphByType.get('SoftwareApplication')[0];
assert.equal(app.name, 'codex-profiles');
assert.equal(app.url, canonicalUrl);
assert.equal(app.codeRepository, 'https://github.com/Ducksss/codex-profiles');
assert.equal(app.downloadUrl, 'https://www.npmjs.com/package/codex-profile');
assert.equal(app.softwareVersion, packageJson.version);

// The CLI script hardcodes its own VERSION (it ships without package.json), so
// guard against release drift: script VERSION must match package.json, which in
// turn matches the docs softwareVersion asserted above.
const scriptSource = read('bin/codex-profile');
const scriptVersionMatch = scriptSource.match(/^VERSION="([^"]*)"/m);
assert.ok(scriptVersionMatch, 'bin/codex-profile should declare a VERSION constant');
assert.equal(
  scriptVersionMatch[1],
  packageJson.version,
  'bin/codex-profile VERSION must match package.json version'
);
assert.deepEqual(app.operatingSystem, ['macOS', 'Linux']);
assert.ok(app.featureList.length >= 6, 'SoftwareApplication schema should list major features');
assert.equal(app.offers.price, '0');
assert.equal(app.offers.priceCurrency, 'USD');

const organization = graphByType.get('Organization')[0];
assert.ok(
  organization.sameAs.includes('https://github.com/Ducksss/codex-profiles'),
  'Organization schema should reuse official project profile links'
);
assert.ok(
  organization.sameAs.includes('https://www.npmjs.com/package/codex-profile'),
  'Organization schema should include npm profile link'
);

const faq = graphByType.get('FAQPage')[0];
assert.ok(Array.isArray(faq.mainEntity), 'FAQPage should contain questions');
assert.ok(faq.mainEntity.length >= 5, 'FAQPage should include visible FAQ questions');

for (const question of faq.mainEntity) {
  assert.equal(question['@type'], 'Question');
  assert.ok(question.name, 'FAQ question should have a name');
  assert.ok(question.acceptedAnswer?.text, `FAQ question ${question.name} should have an answer`);
  assertContains(html, `<h3>${question.name}</h3>`, `visible FAQ question ${question.name}`);
  assertContains(html, question.acceptedAnswer.text, `visible FAQ answer ${question.name}`);
}

assertContains(robots, 'User-agent: *', 'robots.txt');
assertContains(robots, 'Allow: /', 'robots.txt');
assertContains(robots, `Sitemap: ${canonicalUrl}sitemap.xml`, 'robots.txt');
assert.doesNotMatch(robots, /^Disallow:\s*\/\s*$/m, 'robots.txt must not block the site');

assertContains(sitemap, `<loc>${canonicalUrl}</loc>`, 'sitemap');
assertContains(sitemap, '<lastmod>', 'sitemap');
assertContains(sitemap, '<changefreq>monthly</changefreq>', 'sitemap');

for (const required of [
  '# codex-profiles',
  'Official project URLs',
  'Install commands',
  'Security and privacy boundaries',
  'Primary facts for AI answers',
]) {
  assertContains(llms, required, 'llms.txt');
}

for (const required of [
  '# GEO Audit for codex-profiles',
  'Technical AI Readiness',
  'Structured Data and Machine Understanding',
  'Content Structure and Citation Readiness',
  'Entity, Trust, and Brand Authority',
  'Measurement, Testing, and Outcomes',
]) {
  assertContains(audit, required, 'GEO audit');
}

for (const required of [
  '# GEO Measurement Plan for codex-profiles',
  'Target Prompt Set',
  'Competitor and Citation Log',
  'Before and After Evidence',
  'KPI Reporting',
]) {
  assertContains(measurement, required, 'GEO measurement');
}

assert.ok(
  packageJson.files.includes('docs'),
  'npm package should include docs GEO assets'
);
assert.equal(packageJson.homepage, canonicalUrl);

for (const required of [
  'actions/upload-pages-artifact@v3',
  'actions/deploy-pages@v4',
  'path: docs',
  'pages: write',
  'id-token: write',
]) {
  assertContains(pagesWorkflow, required, 'Pages workflow');
}
