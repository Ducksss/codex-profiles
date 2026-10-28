#!/usr/bin/env node

import assert from 'node:assert/strict';
import { createPublicKey } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
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
const body = html.split('<body>')[1].replace(/<script\b[^>]*>[\s\S]*?<\/script>/g, '');
const textContent = (source) => source.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
const robots = read('docs/robots.txt');
const sitemap = read('docs/sitemap.xml');
const llms = read('docs/llms.txt');
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

const title = html.match(/<title>([^<]+)<\/title>/)[1];
const headings = [...body.matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/g)];
assert.equal(headings.length, 1, 'homepage should have one descriptive H1');
assert.match(textContent(headings[0][1]), /Codex profiles/i);
assertContains(html, '<html lang="en">', 'homepage language');
assertContains(body, 'href="#main-content"', 'keyboard skip link');
for (const [attribute, name, value] of [
  ['property', 'og:title', title],
  ['property', 'og:description', pageDescription],
  ['property', 'og:url', canonicalUrl],
  ['name', 'twitter:title', title],
  ['name', 'twitter:description', pageDescription],
  ['name', 'twitter:card', 'summary_large_image'],
]) {
  assertContains(html, `<meta ${attribute}="${name}" content="${value}">`, name);
}

const imageUrl = `${canonicalUrl}og-image.png`;
for (const [attribute, name] of [['property', 'og:image'], ['name', 'twitter:image']]) {
  assertContains(html, `<meta ${attribute}="${name}" content="${imageUrl}">`, name);
}
const socialImage = readFileSync(join(siteRoot, 'og-image.png'));
assert.equal(socialImage.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', 'social image is PNG');
for (const [name, offset] of [['width', 16], ['height', 20]]) {
  assertContains(html, `<meta property="og:image:${name}" content="${socialImage.readUInt32BE(offset)}">`, `social image ${name}`);
}
for (const [attribute, name] of [['property', 'og:image:alt'], ['name', 'twitter:image:alt']]) {
  assert.match(html, new RegExp(`<meta ${attribute}="${name}" content="[^"]+">`));
}

// Check real files, not just the presence of discovery URLs in metadata.
for (const [, target] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
  const url = new URL(target, canonicalUrl);
  if (!url.href.startsWith(canonicalUrl)) continue;
  const path = decodeURIComponent(url.pathname.slice(new URL(canonicalUrl).pathname.length));
  assert.ok(fileExists(`docs/${path || 'index.html'}`), `missing site link or asset: ${target}`);
}
for (const [, image] of body.matchAll(/(<img\b[^>]+>)/g)) {
  assert.match(image, /alt="[^"]+"/, 'content image should have descriptive alt text');
  assert.match(image, /width="\d+"/, 'image should reserve its layout width');
  assert.match(image, /height="\d+"/, 'image should reserve its layout height');
}

assertContains(
  html,
  'Separate CODEX_HOME directories per profile',
  'homepage feature list'
);
for (const staleCopy of [
  'Isolated CODEX_HOME directories per profile',
  'run Codex on isolated work and personal profiles',
  'Example isolated profiles',
  'Interactive isolation model',
  'state bleeds between accounts',
  'Profile isolation at a glance',
  'own isolated home directory',
  '<strong>Profile isolation</strong>',
  'Desktop proof',
  'codex-profile-parallel-instances.png',
]) {
  assert.ok(!html.includes(staleCopy), `homepage should not contain stale copy: ${staleCopy}`);
}
for (const [, anchor] of html.matchAll(/href="#([^"]+)"/g)) {
  assertContains(html, `id="${anchor}"`, `homepage anchor #${anchor}`);
}

assert.ok(statSync(siteRoot).isDirectory(), 'docs site root should exist');
assert.ok(fileExists('docs/index.html'), 'docs/index.html should exist');
assert.ok(fileExists('docs/robots.txt'), 'docs/robots.txt should exist');
assert.ok(fileExists('docs/sitemap.xml'), 'docs/sitemap.xml should exist');
assert.ok(fileExists('docs/llms.txt'), 'docs/llms.txt should exist');
assert.ok(fileExists('docs/.nojekyll'), 'docs/.nojekyll should exist');
assert.ok(fileExists('docs/outreach-jwks.json'), 'public outreach JWKS should exist');
assert.ok(fileExists('ops/outreach/tracker.md'), 'outreach tracker runbook should exist');
assert.ok(fileExists('.github/workflows/pages.yml'), 'Pages deploy workflow should exist');
assert.ok(!fileExists('docs/geo-audit.md'), 'internal GEO audit should not be deployed');
assert.ok(!fileExists('docs/geo-measurement.md'), 'internal GEO measurement plan should not be deployed');
assert.ok(
  !fileExists('media/codex-profile-parallel-instances.png'),
  'obsolete pre-v0.7 Desktop screenshot should not be retained'
);

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

const jsonLdBlocks = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
assert.ok(jsonLdBlocks.length, 'homepage should include JSON-LD');
const graph = jsonLdBlocks.flatMap(([, source]) => {
  const jsonLd = JSON.parse(source);
  assert.equal(jsonLd['@context'], 'https://schema.org');
  assert.ok(Array.isArray(jsonLd['@graph']), 'JSON-LD should use @graph');
  return jsonLd['@graph'];
});
const graphIds = new Set(graph.map((node) => node['@id']));
assert.equal(graphIds.size, graph.length, 'structured identities must not be duplicated');
for (const id of graphIds) {
  assert.ok(id?.startsWith(`${canonicalUrl}#`), `identity must use the canonical site: ${id}`);
}
function checkReferences(value) {
  if (!value || typeof value !== 'object') return;
  if (value['@id']) assert.ok(graphIds.has(value['@id']), `unresolved identity: ${value['@id']}`);
  for (const child of Object.values(value)) checkReferences(child);
}
checkReferences(graph);

const graphByType = new Map();
for (const node of graph) {
  const types = Array.isArray(node['@type']) ? node['@type'] : [node['@type']];
  for (const type of types) {
    if (!graphByType.has(type)) {
      graphByType.set(type, []);
    }
    graphByType.get(type).push(node);
  }
}

for (const type of [
  'Person',
  'SoftwareApplication',
  'SoftwareSourceCode',
  'WebSite',
  'WebPage',
  'FAQPage',
]) {
  assert.ok(graphByType.has(type), `JSON-LD should include ${type}`);
}

const app = graphByType.get('SoftwareApplication')[0];
assert.equal(app.name, 'codex-profiles');
assert.equal(app.url, canonicalUrl);
assert.equal(app.codeRepository, 'https://github.com/Ducksss/codex-profiles');
assert.equal(app.downloadUrl, 'https://www.npmjs.com/package/codex-profile');
assert.equal(app.softwareVersion, packageJson.version);
assert.equal(app.license, 'https://github.com/Ducksss/codex-profiles/blob/main/LICENSE');
assertContains(textContent(body), app.description, 'visible product definition');
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
assert.equal(webPage.name, title, 'page schema title should match the HTML title');
assert.equal(webPage.description, pageDescription, 'page schema description should match metadata');
assert.equal(webPage.url, canonicalUrl);
const modified = body.match(/Page updated <time datetime="(\d{4}-\d{2}-\d{2})">\1<\/time>/);
assert.ok(modified, 'homepage should state its editorial date visibly');
const modifiedDate = modified[1];
assert.equal(new Date(`${modifiedDate}T00:00:00Z`).toISOString().slice(0, 10), modifiedDate);
assert.equal(
  webPage.dateModified,
  modifiedDate,
  'WebPage dateModified should match the editorial date, not the software release'
);

const maintainer = graphByType.get('Person')[0];
assert.equal(maintainer.name, 'Ducksss');
assert.equal(maintainer.url, 'https://github.com/Ducksss');
assertContains(body, `<a href="${maintainer.url}">${maintainer.name}</a>`, 'visible maintainer');
assert.equal(app.maintainer['@id'], maintainer['@id']);
assert.equal(graphByType.get('WebSite')[0].publisher['@id'], maintainer['@id']);
assert.ok(!graphByType.has('Organization'), 'do not invent an organization for an individual-maintained project');
assert.ok(
  app.sameAs.includes('https://github.com/Ducksss/codex-profiles'),
  'software identity should reuse the project repository'
);
assert.ok(
  app.sameAs.includes('https://www.npmjs.com/package/codex-profile'),
  'software identity should reuse the npm package'
);

const faq = graphByType.get('FAQPage')[0];
assert.ok(Array.isArray(faq.mainEntity), 'FAQPage should contain questions');
assert.ok(faq.mainEntity.length >= 5, 'FAQPage should include visible FAQ questions');

for (const question of faq.mainEntity) {
  assert.equal(question['@type'], 'Question');
  assert.ok(question.name, 'FAQ question should have a name');
  assert.ok(question.acceptedAnswer?.text, `FAQ question ${question.name} should have an answer`);
  assert.equal(question.acceptedAnswer['@type'], 'Answer');
}
// Never search the full document: the JSON-LD itself would satisfy a stale answer.
const visibleFaq = [...body.matchAll(/<article>\s*<h3>([\s\S]*?)<\/h3>\s*<p>([\s\S]*?)<\/p>\s*<\/article>/g)]
  .map(([, question, answer]) => ({ question: textContent(question), answer: textContent(answer) }));
assert.deepEqual(
  visibleFaq,
  faq.mainEntity.map((question) => ({ question: question.name, answer: question.acceptedAnswer.text })),
  'every structured FAQ answer must match its visible article, with no missing or extra answers'
);

assertContains(robots, 'User-agent: *', 'robots.txt');
assertContains(robots, 'Allow: /', 'robots.txt');
assertContains(robots, `Sitemap: ${canonicalUrl}sitemap.xml`, 'robots.txt');
assert.doesNotMatch(robots, /^Disallow:\s*\/\s*$/m, 'robots.txt must not block the site');
assertContains(robots, 'https://ducksss.github.io/robots.txt', 'host-root robots scope');

assertContains(sitemap, `<loc>${canonicalUrl}</loc>`, 'sitemap');
assertContains(sitemap, 'xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"', 'sitemap namespace');
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
    { location: canonicalUrl, lastModified: modifiedDate },
  ],
  'sitemap should pair canonical HTML with its editorial date'
);
assert.deepEqual(
  [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(([, url]) => url),
  readdirSync(siteRoot, { recursive: true }).filter((path) => path.endsWith('.html'))
    .map((path) => `${canonicalUrl}${path === 'index.html' ? '' : path}`).sort(),
  'every public HTML page needs a canonical sitemap entry, without duplicate text references'
);
assertContains(body, `releases/tag/v${packageJson.version}">${packageJson.version}</a>, dated ${releaseDate}.`, 'visible software release');
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

for (const [type, url] of [
  ['text/plain', `${canonicalUrl}llms.txt`],
  ['application/atom+xml', 'https://github.com/Ducksss/codex-profiles/releases.atom'],
]) {
  assert.match(html, new RegExp(`<link rel="alternate" type="${type.replace('+', '\\+')}"[^>]+href="${url.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}">`));
  assertContains(body, `href="${url}"`, 'visible reference/feed link');
}
for (const document of ['README.md', 'USAGE.md', 'agent.md', 'macos/README.md', 'SECURITY.md']) {
  assert.ok(fileExists(document), `primary source should exist: ${document}`);
  assertContains(body, `href="https://github.com/Ducksss/codex-profiles/blob/main/${document}`, 'visible primary source');
  assertContains(llms, `https://raw.githubusercontent.com/Ducksss/codex-profiles/main/${document}`, 'plain-text primary source');
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

// Moving reference material must not strand links in either entry point.
for (const document of ['README.md', 'USAGE.md']) {
  const markdown = read(document);
  for (const [, target] of markdown.matchAll(/\]\(([^\s)]+)\)/g)) {
    if (/^[a-z]+:\/\//i.test(target)) continue;
    const [path, anchor] = target.split('#');
    const destination = path || document;
    assert.ok(fileExists(destination), `${document}: missing link target ${target}`);
    if (anchor && destination.endsWith('.md')) {
      const headings = [...read(destination).matchAll(/^#{1,6} (.+)$/gm)].map(([, heading]) =>
        heading.toLowerCase().replace(/[^\p{L}\p{N}_\-\s]/gu, '').replace(/ /g, '-')
      );
      assert.ok(headings.includes(anchor), `${document}: missing heading ${target}`);
    }
  }
}
for (const asset of ['USAGE.md']) {
  assert.ok(packageJson.files.includes(asset), `npm package must include README dependency ${asset}`);
}
