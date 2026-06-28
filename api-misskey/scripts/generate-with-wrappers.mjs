#!/usr/bin/env node
// Generate Misskey API with NEW thin wrapper and TypeScript support
// This example shows how to enable ALL new features

import { generate } from '../../rescript-codegen-openapi/src/Codegen.mjs';
import { mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function main() {
  console.log('🚀 Generating Misskey API with ALL new features enabled\n');
  console.log('   ✨ Base ReScript API');
  console.log('   ✨ ReScript Thin Wrapper (pipe-first)');
  console.log('   ✨ TypeScript .d.ts definitions');
  console.log('   ✨ TypeScript/JavaScript wrapper\n');
  
  const outputDir = join(__dirname, '../src/generated');
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Fetching API spec from Misskey.io...\n');
  
  const result = await generate({
    specPath: 'https://misskey.io/api.json',
    outputDir,
    strategy: 'SharedBase',
    modulePerTag: true,
    generateDiffReport: false,
    breakingChangeHandling: 'Warn',
    
    // NEW: Enable all generation targets!
    targets: {
      rescriptApi: true,        // ✅ Base ReScript API
      rescriptWrapper: true,    // ✅ NEW: Pipe-first wrapper
      typescriptDts: true,      // ✅ NEW: TypeScript definitions
      typescriptWrapper: true,  // ✅ NEW: TypeScript wrapper
    },
    
    // Optional: Customize output locations
    dtsOutputDir: join(__dirname, '../src/types'),
    wrapperOutputDir: join(__dirname, '../src'),
  });
  
  if (result.TAG === 'Ok') {
    const { generatedFiles } = result._0;
    
    console.log('✅ Generation complete!\n');
    console.log(`📁 Generated ${generatedFiles.length} files\n`);
    
    console.log('📂 Output structure:');
    console.log('   src/generated/           - Base ReScript API');
    console.log('   src/Misskey.res          - ReScript thin wrapper 🆕');
    console.log('   src/types/               - TypeScript .d.ts files 🆕');
    console.log('   src/wrapper/             - TypeScript wrapper 🆕\n');
    
    console.log('🎯 Usage Examples:\n');
    
    console.log('📘 ReScript (Pipe-First):');
    console.log('   let client = Misskey.connect("https://misskey.io", ~token="...", ())');
    console.log('   {text: "Hello"}->Misskey.Notes.postNotesCreate(~client)\n');
    
    console.log('📗 TypeScript:');
    console.log('   import { MisskeyClient, Notes } from "./wrapper"');
    console.log('   const client = new MisskeyClient("https://misskey.io", "token")');
    console.log('   await Notes.postNotesCreate(client, { text: "Hello" })\n');
    
    console.log('🌟 New Features:');
    console.log('   ✨ Pipe-first ReScript API (no manual fetch wiring!)');
    console.log('   💡 Full TypeScript IntelliSense');
    console.log('   🔒 Type-safe client management');
    console.log('   📦 Tree-shakeable ES modules\n');
    
  } else {
    console.error('❌ Generation failed:', result._0);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
