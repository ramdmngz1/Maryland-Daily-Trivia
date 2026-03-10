#!/usr/bin/env node
/**
 * sync-questions.js
 *
 * Pulls all questions from D1 and writes them to the iOS questions_md.json bundle.
 * Run this any time questions are added to D1 to keep the app in sync.
 *
 * Usage:
 *   node scripts/sync-questions.js
 *   node scripts/sync-questions.js --env staging
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DB_NAME = 'maryland-trivia-contest';
const OUT_PATH = path.resolve(__dirname, '../../iOS/Maryland Daily Trivia/Maryland Daily Trivia/questions_md.json');

const args = process.argv.slice(2);
const envFlag = args.includes('--env') ? `--env ${args[args.indexOf('--env') + 1]}` : '';

console.log(`Fetching questions from D1 (${DB_NAME})...`);

let raw;
try {
  raw = execSync(
    `wrangler d1 execute ${DB_NAME} ${envFlag} --json --command "SELECT id, category, difficulty, question, choices, correct_index, explanation FROM questions ORDER BY id"`,
    { cwd: path.resolve(__dirname, '..') }
  ).toString();
} catch (err) {
  console.error('Failed to query D1. Make sure you are logged in with: wrangler login');
  process.exit(1);
}

let rows;
try {
  const parsed = JSON.parse(raw);
  rows = parsed[0].results;
} catch (err) {
  console.error('Failed to parse wrangler output:', err.message);
  process.exit(1);
}

const questions = rows.map(r => {
  let choices = r.choices;
  if (typeof choices === 'string') {
    try { choices = JSON.parse(choices); } catch { choices = []; }
  }
  return {
    id: r.id,
    category: r.category,
    difficulty: r.difficulty,
    question: r.question,
    choices,
    correctIndex: r.correct_index,
    explanation: r.explanation || '',
  };
});

fs.writeFileSync(OUT_PATH, JSON.stringify(questions, null, 2), 'utf8');

console.log(`Done. ${questions.length} questions written to:`);
console.log(`  ${OUT_PATH}`);
