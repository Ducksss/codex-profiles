#!/usr/bin/env node

import assert from 'node:assert/strict';
import { createPublicKey } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
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
const agentsGuide = read('AGENTS.md');
const setupAgent = read('agent.md');
const securityPolicy = read('SECURITY.md');
const pagesWorkflow = read('.github/workflows/pages.yml');
const changelog = read('CHANGELOG.md');
const packageJson = JSON.parse(read('package.json'));
const outreachJwks = JSON.parse(read('docs/outreach-jwks.json'));

const escapedVersion = packageJson.version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const releaseHeading = changelog.match(
  new RegExp(`^## ${escapedVersion} - (\\d{4}-\\d{2}-\\d{2})$`, 'm')
);
assert.ok(
  releaseHeading,
  `CHANGELOG.md should contain a dated ${packageJson.version} release heading`
);
const releaseDate = releaseHeading[1];
const releaseTimestamp = Date.parse(`${releaseDate}T00:00:00Z`);
assert.ok(Number.isFinite(releaseTimestamp), 'release date should be a real UTC date');
assert.equal(
  new Date(releaseTimestamp).toISOString().slice(0, 10),
  releaseDate,
  'release date should round-trip without calendar normalization'
);

const descriptionMatch = html.match(/<meta name="description" content="([^"]+)">/);
assert.ok(descriptionMatch, 'homepage should include a meta description');
const pageDescription = descriptionMatch[1];
assertContains(
  pageDescription,
  'separate local state',
  'homepage meta description'
);

assert.ok(statSync(siteRoot).isDirectory(), 'docs site root should exist');
assert.ok(fileExists('docs/index.html'), 'docs/index.html should exist');
assert.ok(fileExists('docs/robots.txt'), 'docs/robots.txt should exist');
assert.ok(fileExists('docs/sitemap.xml'), 'docs/sitemap.xml should exist');
assert.ok(fileExists('docs/llms.txt'), 'docs/llms.txt should exist');
assert.ok(fileExists('docs/geo-audit.md'), 'docs/geo-audit.md should exist');
assert.ok(fileExists('docs/geo-measurement.md'), 'docs/geo-measurement.md should exist');
assert.ok(fileExists('docs/.nojekyll'), 'docs/.nojekyll should exist');
assert.ok(fileExists('docs/outreach-jwks.json'), 'public outreach JWKS should exist');
assert.ok(fileExists('ops/outreach/tracker.md'), 'outreach tracker runbook should exist');
assert.ok(fileExists('.github/workflows/pages.yml'), 'Pages deploy workflow should exist');

assert.equal(outreachJwks.keys.length, 1, 'outreach JWKS should publish one active key');
const outreachJwk = outreachJwks.keys[0];
assert.equal(outreachJwk.kty, 'RSA');
assert.equal(outreachJwk.alg, 'RS256');
assert.equal(outreachJwk.use, 'sig');
assert.ok(outreachJwk.kid, 'outreach JWKS should include a key id');
for (const privateField of ['d', 'p', 'q', 'dp', 'dq', 'qi']) {
  assert.equal(outreachJwk[privateField], undefined, `JWKS must not expose ${privateField}`);
}
assert.equal(
  createPublicKey({ key: outreachJwk, format: 'jwk' }).asymmetricKeyDetails.modulusLength,
  3072,
  'outreach signing key should be 3072 bits'
);

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
assertContains(
  app.description,
  'separate local state',
  'SoftwareApplication description'
);

for (const [label, summary] of [
  ['homepage meta description', pageDescription],
  ['SoftwareApplication description', app.description],
  ['package description', packageJson.description],
]) {
  assert.doesNotMatch(
    summary,
    /isolated local ChatGPT|isolated ChatGPT desktop sessions|account isolation/i,
    `${label} must describe local-state separation without an account-isolation claim`
  );
}

for (const [label, guidance] of [
  ['AGENTS.md', agentsGuide],
  ['agent.md', setupAgent],
  ['SECURITY.md', securityPolicy],
]) {
  const normalizedGuidance = guidance.replace(/\s+/g, ' ');
  assertContains(
    normalizedGuidance,
    'named ChatGPT windows with separate local state',
    label
  );
  assertContains(
    normalizedGuidance,
    'Local-state separation is not an account, OS, or server-side boundary.',
    label
  );
  assert.doesNotMatch(
    normalizedGuidance,
    /isolated\s+(?:local\s+)?ChatGPT desktop windows|named local ChatGPT desktop windows|account separation matters|separate accounts|isolated accounts|identity isolation|local identity boundary|isolation boundary|profile isolation/i,
    `${label} must not imply verified account or identity isolation`
  );
}

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

const webPage = graphByType.get('WebPage')[0];
assert.equal(
  webPage.dateModified,
  releaseDate,
  'WebPage dateModified should match the changelog release date'
);

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
assertContains(sitemap, '<changefreq>monthly</changefreq>', 'sitemap');
const sitemapEntries = [
  ...sitemap.matchAll(
    /<url>\s*<loc>([^<]+)<\/loc>\s*<lastmod>([^<]+)<\/lastmod>[\s\S]*?<\/url>/g
  ),
].map(
  (match) => ({ location: match[1], lastModified: match[2] })
);
assert.deepEqual(
  sitemapEntries,
  [
    { location: canonicalUrl, lastModified: releaseDate },
    { location: `${canonicalUrl}llms.txt`, lastModified: releaseDate },
  ],
  'sitemap should pair each public URL with the changelog release date'
);
assertContains(html, `Last updated ${releaseDate}.`, 'homepage footer');
assertContains(audit, `${releaseDate} modification dates`, 'GEO audit sitemap date');
assertContains(audit, `as of ${releaseDate}`, 'GEO audit facts date');
assertContains(audit, 'make check', 'GEO audit validation command');
assertContains(html, 'uses make check', 'homepage validation description');
assertContains(
  llms,
  `The current release is \`${packageJson.version}\`, dated ${releaseDate}.`,
  'llms.txt release metadata'
);

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
  packageJson.files.includes('docs/llms.txt'),
  'npm package should include the machine-readable product summary'
);
assert.ok(!packageJson.files.includes('docs'), 'npm package should exclude the Pages source');
assert.equal(packageJson.homepage, canonicalUrl);

for (const required of [
  'actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9 # v5',
  'actions/deploy-pages@cd2ce8fcbc39b97be8ca5fce6e763baed58fa128 # v5',
  'path: .pages-site/docs',
  'pages: write',
  'id-token: write',
]) {
  assertContains(pagesWorkflow, required, 'Pages workflow');
}
