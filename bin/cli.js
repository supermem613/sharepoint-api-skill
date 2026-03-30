#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

// ── ANSI colors ──────────────────────────────────────────────────────────────
const C = {
  reset:   '\x1b[0m',
  bold:    '\x1b[1m',
  dim:     '\x1b[2m',
  green:   '\x1b[32m',
  yellow:  '\x1b[33m',
  cyan:    '\x1b[36m',
  red:     '\x1b[31m',
  magenta: '\x1b[35m',
};

const ok   = (msg) => console.log(`${C.green}${C.bold}  ✔ ${C.reset}${C.green}${msg}${C.reset}`);
const info = (msg) => console.log(`${C.cyan}  ℹ ${msg}${C.reset}`);
const warn = (msg) => console.log(`${C.yellow}  ⚠ ${msg}${C.reset}`);
const fail = (msg) => { console.error(`${C.red}${C.bold}  ✖ ${C.reset}${C.red}${msg}${C.reset}`); };

// ── Paths ────────────────────────────────────────────────────────────────────
const PKG_ROOT = path.resolve(__dirname, '..');
const SKILL_MD   = path.join(PKG_ROOT, 'SKILL.md');
const SCRIPTS    = path.join(PKG_ROOT, 'scripts');
const REFERENCES = path.join(PKG_ROOT, 'references');
const HOME       = os.homedir();

// ── Helpers ──────────────────────────────────────────────────────────────────

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function copyDirIfExists(src, dest) {
  if (!fs.existsSync(src)) {
    warn(`Source not found, skipping: ${src}`);
    return false;
  }
  ensureDir(dest);
  fs.cpSync(src, dest, { recursive: true, force: true });
  return true;
}

function copyFileIfExists(src, dest) {
  if (!fs.existsSync(src)) {
    warn(`Source not found, skipping: ${src}`);
    return false;
  }
  ensureDir(path.dirname(dest));
  fs.copyFileSync(src, dest);
  return true;
}

function readSkillMd() {
  if (!fs.existsSync(SKILL_MD)) {
    throw new Error(`SKILL.md not found at ${SKILL_MD}`);
  }
  return fs.readFileSync(SKILL_MD, 'utf-8');
}

// ── Platform installers ──────────────────────────────────────────────────────

function installClaude(cwd, global) {
  const targetBase = global
    ? path.join(HOME, '.claude', 'skills', 'sharepoint-api')
    : path.join(cwd, '.claude', 'skills', 'sharepoint-api');

  console.log();
  info(`Installing for ${C.bold}Claude Code${C.reset}${C.cyan} → ${targetBase}`);

  ensureDir(targetBase);

  copyFileIfExists(SKILL_MD, path.join(targetBase, 'SKILL.md'));
  copyDirIfExists(SCRIPTS, path.join(targetBase, 'scripts'));
  copyDirIfExists(REFERENCES, path.join(targetBase, 'references'));

  ok(`Claude Code skill installed${global ? ' (global)' : ''}`);
}

function installCopilot(cwd) {
  const githubDir = path.join(cwd, '.github');
  const instrFile = path.join(githubDir, 'copilot-instructions.md');
  const scriptsDir = path.join(githubDir, 'sharepoint-api', 'scripts');

  console.log();
  info(`Installing for ${C.bold}GitHub Copilot${C.reset}${C.cyan} → ${githubDir}`);

  const skillContent = readSkillMd();
  const header = [
    '<!-- AUTO-GENERATED from sharepoint-api-skill SKILL.md — do not edit by hand -->',
    '<!-- Re-run: npx sharepoint-api-skill init --ai copilot -->',
    '',
  ].join('\n');

  ensureDir(githubDir);

  // Append to existing copilot-instructions.md if it already exists
  if (fs.existsSync(instrFile)) {
    const existing = fs.readFileSync(instrFile, 'utf-8');
    if (existing.includes('sharepoint-api-skill')) {
      warn('copilot-instructions.md already contains SharePoint API skill — overwriting section');
    }
    // If file exists but doesn't have our content, append
    if (!existing.includes('sharepoint-api-skill')) {
      fs.appendFileSync(instrFile, '\n\n' + header + skillContent + '\n');
    } else {
      fs.writeFileSync(instrFile, header + skillContent + '\n');
    }
  } else {
    fs.writeFileSync(instrFile, header + skillContent + '\n');
  }

  copyDirIfExists(SCRIPTS, scriptsDir);

  ok('GitHub Copilot instructions installed');
}

function installCodex(cwd, global) {
  console.log();

  if (global) {
    const codexDir = path.join(HOME, '.codex');
    const instrFile = path.join(codexDir, 'instructions.md');

    info(`Installing for ${C.bold}Codex${C.reset}${C.cyan} (global) → ${instrFile}`);

    const skillContent = readSkillMd();
    const header = [
      '<!-- AUTO-GENERATED from sharepoint-api-skill SKILL.md — do not edit by hand -->',
      '<!-- Re-run: npx sharepoint-api-skill init --ai codex --global -->',
      '',
    ].join('\n');

    ensureDir(codexDir);
    fs.writeFileSync(instrFile, header + skillContent + '\n');

    ok('Codex global instructions installed');
  } else {
    const instrFile = path.join(cwd, 'codex.md');
    const scriptsDir = path.join(cwd, 'sharepoint-api', 'scripts');

    info(`Installing for ${C.bold}Codex${C.reset}${C.cyan} → ${instrFile}`);

    const skillContent = readSkillMd();
    const header = [
      '<!-- AUTO-GENERATED from sharepoint-api-skill SKILL.md — do not edit by hand -->',
      '<!-- Re-run: npx sharepoint-api-skill init --ai codex -->',
      '',
    ].join('\n');

    fs.writeFileSync(instrFile, header + skillContent + '\n');
    copyDirIfExists(SCRIPTS, scriptsDir);

    ok('Codex instructions installed');
  }
}

// ── Help text ────────────────────────────────────────────────────────────────

function printHelp() {
  console.log(`
${C.bold}${C.magenta}sharepoint-api-skill${C.reset} — AI skill installer for SharePoint API automation

${C.bold}USAGE${C.reset}
  npx sharepoint-api-skill init --ai <platform> [--global]

${C.bold}PLATFORMS${C.reset}
  ${C.cyan}claude${C.reset}    Install for Claude Code (.claude/skills/sharepoint-api/)
  ${C.cyan}copilot${C.reset}   Install for GitHub Copilot (.github/copilot-instructions.md)
  ${C.cyan}codex${C.reset}     Install for Codex (codex.md)
  ${C.cyan}all${C.reset}       Install for all platforms

${C.bold}OPTIONS${C.reset}
  --global    Install to user home directory instead of current project
  --help      Show this help message

${C.bold}EXAMPLES${C.reset}
  ${C.dim}npx sharepoint-api-skill init --ai claude${C.reset}
  ${C.dim}npx sharepoint-api-skill init --ai copilot${C.reset}
  ${C.dim}npx sharepoint-api-skill init --ai codex${C.reset}
  ${C.dim}npx sharepoint-api-skill init --ai all${C.reset}
  ${C.dim}npx sharepoint-api-skill init --ai claude --global${C.reset}
`);
}

// ── Arg parsing ──────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = argv.slice(2);
  const result = { command: null, ai: null, global: false, help: false };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--help' || arg === '-h') {
      result.help = true;
    } else if (arg === '--global' || arg === '-g') {
      result.global = true;
    } else if (arg === '--ai' && i + 1 < args.length) {
      result.ai = args[++i].toLowerCase();
    } else if (!arg.startsWith('-')) {
      result.command = arg.toLowerCase();
    }
  }

  return result;
}

// ── Main ─────────────────────────────────────────────────────────────────────

function main() {
  const opts = parseArgs(process.argv);
  const cwd = process.cwd();

  if (opts.help || (!opts.command && !opts.ai)) {
    printHelp();
    process.exit(0);
  }

  if (opts.command !== 'init') {
    fail(`Unknown command: "${opts.command}". Use "init".`);
    printHelp();
    process.exit(1);
  }

  const validPlatforms = ['claude', 'copilot', 'codex', 'all'];
  if (!opts.ai || !validPlatforms.includes(opts.ai)) {
    fail(`Missing or invalid --ai platform. Choose: ${validPlatforms.join(', ')}`);
    printHelp();
    process.exit(1);
  }

  console.log();
  console.log(`${C.bold}${C.magenta}  sharepoint-api-skill${C.reset} installer`);
  console.log(`${C.dim}  ─────────────────────────────${C.reset}`);

  try {
    const platforms = opts.ai === 'all' ? ['claude', 'copilot', 'codex'] : [opts.ai];

    for (const platform of platforms) {
      switch (platform) {
        case 'claude':
          installClaude(cwd, opts.global);
          break;
        case 'copilot':
          installCopilot(cwd);
          break;
        case 'codex':
          installCodex(cwd, opts.global);
          break;
      }
    }

    console.log();
    ok(`Done! SharePoint API skill is ready.`);
    console.log();
  } catch (err) {
    console.log();
    fail(err.message);
    process.exit(1);
  }
}

main();
