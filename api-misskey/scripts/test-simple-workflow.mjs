#!/usr/bin/env node

/**
 * Test the simplified doc override workflow
 * - No auto-refresh
 * - Users manually delete outdated files
 * - Clear warnings guide the process
 */

import { generate } from '../../rescript-codegen-openapi/src/Codegen.mjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const TEST_OUTPUT = path.join(__dirname, '../src/test-simple');
const TEST_OVERRIDES = path.join(__dirname, '../docs/test-simple-overrides');

// Clean up
[TEST_OUTPUT, TEST_OVERRIDES].forEach(dir => {
  if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
});

console.log('===== SIMPLIFIED DOC OVERRIDE WORKFLOW =====\n');

console.log('Step 1: Generate code with override files');
await generate({
  specPath: 'https://misskey.noellabo.jp/api.json',
  outputDir: TEST_OUTPUT,
  generateDocOverrides: true,
  docOverrideDir: TEST_OVERRIDES,
  modulePerTag: false,
  includeDeprecated: false,
});

const apiDir = path.join(TEST_OVERRIDES, 'Api');
const files = fs.readdirSync(apiDir).filter(f => f.endsWith('.md'));
const testFile = path.join(apiDir, files[0]);
console.log(`✅ Generated override files in ${apiDir}/`);
console.log(`✅ Using test file: ${files[0]}\n`);

console.log('Step 2: Add custom documentation');
const content = fs.readFileSync(testFile, 'utf8');
const customDocs = `**Custom documentation for this endpoint!**

This is my own description that I carefully wrote.`;

const updatedContent = content.replace(
  /(## Override[\s\S]*?```\n)([\s\S]*?)(```)/,
  `$1${customDocs}\n$3`
);
fs.writeFileSync(testFile, updatedContent);
console.log('✅ Added custom documentation\n');

console.log('Step 3: Regenerate - customized file is protected');
await generate({
  specPath: 'https://misskey.noellabo.jp/api.json',
  outputDir: TEST_OUTPUT,
  generateDocOverrides: true, // Try to regenerate
  docOverrideDir: TEST_OVERRIDES,
  modulePerTag: false,
  includeDeprecated: false,
});

const afterRegen = fs.readFileSync(testFile, 'utf8');
if (afterRegen.includes('Custom documentation')) {
  console.log('✅ Custom documentation preserved (file was skipped)\n');
} else {
  console.error('❌ Custom documentation was lost!');
  process.exit(1);
}

console.log('Step 4: Simulate API change by corrupting hash');
const corrupted = afterRegen.replace(/hash: [a-f0-9]+/, 'hash: OUTDATED');
fs.writeFileSync(testFile, corrupted);
console.log('✅ Hash corrupted to simulate API change\n');

console.log('Step 5: Regenerate - hash mismatch warning appears');
console.log('========== WATCH FOR WARNING ==========\n');
await generate({
  specPath: 'https://misskey.noellabo.jp/api.json',
  outputDir: TEST_OUTPUT,
  docOverrideDir: TEST_OVERRIDES,
  modulePerTag: false,
  includeDeprecated: false,
});
console.log('\n========== END ==========\n');

console.log('Step 6: User workflow to fix outdated file:');
console.log('   1. Check git diff to see custom documentation');
console.log('   2. Delete the outdated file');
console.log('   3. Regenerate to get new template');
console.log('   4. Re-add custom documentation');

console.log('\nSimulating user deleting the file...');
fs.unlinkSync(testFile);
console.log('✅ File deleted\n');

console.log('Regenerating to get fresh template...');
await generate({
  specPath: 'https://misskey.noellabo.jp/api.json',
  outputDir: TEST_OUTPUT,
  generateDocOverrides: true,
  docOverrideDir: TEST_OVERRIDES,
  modulePerTag: false,
  includeDeprecated: false,
});

if (fs.existsSync(testFile)) {
  const freshContent = fs.readFileSync(testFile, 'utf8');
  if (!freshContent.includes('Custom documentation')) {
    console.log('✅ Fresh template generated (no custom content)\n');
  } else {
    console.error('❌ Unexpected: found custom content in fresh file');
    process.exit(1);
  }
} else {
  console.error('❌ File was not regenerated!');
  process.exit(1);
}

console.log('===== WORKFLOW COMPLETE! =====\n');
console.log('Summary:');
console.log('✅ Override files are never overwritten if customized');
console.log('✅ Hash mismatch warnings are clear and actionable');
console.log('✅ No complex auto-refresh - users have full control');
console.log('✅ Git-friendly workflow - users see exactly what changed');

console.log('\nCleaning up...');
[TEST_OUTPUT, TEST_OVERRIDES].forEach(dir => {
  if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
});
console.log('✅ Done!\n');
