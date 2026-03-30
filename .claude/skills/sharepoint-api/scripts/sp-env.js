#!/usr/bin/env node
// ============================================================================
// sp-env.js — Shared auth loader for SharePoint API scripts
// ============================================================================
// Loads auth credentials from environment variables first, then falls back
// to ~/.sharepoint-api-skill/auth.json (written by sp-auth.js).
//
// Usage:  const env = require('./sp-env');
//         // env.SP_SITE, env.SP_COOKIES, env.SP_TOKEN, env.GRAPH_TOKEN
// ============================================================================
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const AUTH_FILE = path.join(os.homedir(), '.sharepoint-api-skill', 'auth.json');

function loadAuthFile() {
  try {
    return JSON.parse(fs.readFileSync(AUTH_FILE, 'utf8'));
  } catch {
    return {};
  }
}

function resolve(envName, fileData) {
  return process.env[envName] || fileData[envName] || '';
}

const fileData = loadAuthFile();

module.exports = {
  SP_SITE: resolve('SP_SITE', fileData),
  SP_COOKIES: resolve('SP_COOKIES', fileData),
  SP_TOKEN: resolve('SP_TOKEN', fileData),
  GRAPH_TOKEN: resolve('GRAPH_TOKEN', fileData),
  AUTH_FILE,
};
