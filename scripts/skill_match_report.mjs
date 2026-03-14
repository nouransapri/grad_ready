#!/usr/bin/env node
/**
 * GradReady Skill Match Report (Node.js)
 * Same logic as skill_match_report.py: load users/jobs from CSV, compute match %, output CSV + table.
 * Match % = (matching skills / total required skills) * 100. Recommend if match >= 70%.
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function normalizeSkill(s) {
  if (typeof s !== "string" || !s) return "";
  return s.trim().toLowerCase().replace(/\s+/g, " ");
}

function parseSkillsCell(cell) {
  if (cell == null || typeof cell !== "string") return [];
  const s = cell.trim();
  if (!s) return [];
  const sep = s.includes("|") ? "|" : ",";
  return s.split(sep).map((p) => p.trim()).filter(Boolean);
}

function loadUsersFromCsv(usersPath) {
  const full = path.isAbsolute(usersPath) ? usersPath : path.join(__dirname, usersPath);
  if (!fs.existsSync(full)) return [];
  const text = fs.readFileSync(full, "utf-8");
  const lines = text.split(/\r?\n/).filter((l) => l.trim());
  const header = lines[0].split(",").map((h) => h.trim().replace(/^"|"$/g, ""));
  const idIdx = header.indexOf("user_id") >= 0 ? header.indexOf("user_id") : header.indexOf("id");
  const skillsIdx = header.indexOf("skills") >= 0 ? header.indexOf("skills") : header.indexOf("skill_list");
  if (idIdx < 0 || skillsIdx < 0) return [];
  const users = [];
  for (let i = 1; i < lines.length; i++) {
    const row = parseCsvLine(lines[i]);
    const id = (row[idIdx] || "").trim().replace(/^"|"$/g, "");
    const raw = (row[skillsIdx] || "").trim().replace(/^"|"$/g, "");
    if (!id) continue;
    users.push({ id, skills: parseSkillsCell(raw) });
  }
  return users;
}

function parseCsvLine(line) {
  const out = [];
  let cur = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"') {
      inQuotes = !inQuotes;
    } else if ((c === "," && !inQuotes) || (c === "\n" && !inQuotes)) {
      out.push(cur);
      cur = "";
    } else {
      cur += c;
    }
  }
  out.push(cur);
  return out;
}

function loadJobsFromCsv(jobsPath) {
  const full = path.isAbsolute(jobsPath) ? jobsPath : path.join(__dirname, jobsPath);
  if (!fs.existsSync(full)) return [];
  const text = fs.readFileSync(full, "utf-8");
  const lines = text.split(/\r?\n/).filter((l) => l.trim());
  const header = lines[0].split(",").map((h) => h.trim().replace(/^"|"$/g, ""));
  const idIdx = header.indexOf("job_id") >= 0 ? header.indexOf("job_id") : header.indexOf("id");
  const reqIdx = header.indexOf("required_skills") >= 0 ? header.indexOf("required_skills") : header.indexOf("skills");
  if (idIdx < 0 || reqIdx < 0) return [];
  const jobs = [];
  for (let i = 1; i < lines.length; i++) {
    const row = parseCsvLine(lines[i]);
    const id = (row[idIdx] || "").trim().replace(/^"|"$/g, "");
    const raw = (row[reqIdx] || "").trim().replace(/^"|"$/g, "");
    if (!id) continue;
    jobs.push({ id, required_skills: parseSkillsCell(raw) });
  }
  return jobs;
}

function matchPercentage(userSkills, jobRequired) {
  if (!jobRequired.length) return 100;
  const userSet = new Set(userSkills.map(normalizeSkill).filter(Boolean));
  const requiredNorm = jobRequired.map(normalizeSkill).filter(Boolean);
  if (!requiredNorm.length) return 100;
  const matched = requiredNorm.filter((r) => userSet.has(r)).length;
  return Math.round((matched / requiredNorm.length) * 10000) / 100;
}

function runReport(users, jobs, threshold = 70) {
  const rows = [];
  for (const u of users) {
    for (const j of jobs) {
      const pct = matchPercentage(u.skills, j.required_skills);
    rows.push({
      user_id: u.id,
      job_id: j.id,
      match_percentage: pct,
      recommend: pct >= threshold,
    });
    }
  }
  return rows;
}

function main() {
  const usersPath = process.argv.find((a, i) => process.argv[i - 1] === "--users") || "data/users.csv";
  const jobsPath = process.argv.find((a, i) => process.argv[i - 1] === "--jobs") || "data/jobs.csv";
  const outArg = process.argv.find((a, i) => process.argv[i - 1] === "--output");
  const outputPath = outArg || path.join(__dirname, "out", "skill_match_results.csv");
  const threshold = 70;

  const users = loadUsersFromCsv(usersPath);
  const jobs = loadJobsFromCsv(jobsPath);
  if (!users.length) {
    console.error("No users loaded. Use --users path/to/users.csv");
    process.exit(1);
  }
  if (!jobs.length) {
    console.error("No jobs loaded. Use --jobs path/to/jobs.csv");
    process.exit(1);
  }

  const rows = runReport(users, jobs, threshold);
  const outDir = path.dirname(outputPath);
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const csvLines = ["user_id,job_id,match_percentage,recommend"];
  rows.forEach((r) => csvLines.push(`${r.user_id},${r.job_id},${r.match_percentage},${r.recommend}`));
  fs.writeFileSync(outputPath, csvLines.join("\n"), "utf-8");
  console.log(`Wrote ${rows.length} rows to ${outputPath}\n`);

  console.log("--- Sample (first 20 rows) ---");
  const cols = ["user_id", "job_id", "match_percentage", "recommend"];
  const sample = rows.slice(0, 20);
  const widths = cols.map((c) => Math.max(c.length, ...sample.map((r) => String(r[c]).length)));
  const header = cols.map((c, i) => c.padEnd(widths[i])).join(" | ");
  console.log(header);
  console.log("-".repeat(header.length));
  sample.forEach((r) => console.log(cols.map((c, i) => String(r[c]).padEnd(widths[i])).join(" | ")));
  if (rows.length > 20) console.log(`... and ${rows.length - 20} more rows\n`);

  const recCount = rows.filter((r) => r.recommend).length;
  console.log(`--- Recommendations: ${recCount} user-job pairs with match >= ${threshold}% ---`);
  rows.filter((r) => r.recommend).slice(0, 15).forEach((r) => {
    console.log(`  user_id=${r.user_id}, job_id=${r.job_id}, match=${r.match_percentage}%`);
  });
  if (recCount > 15) console.log(`  ... and ${recCount - 15} more (see CSV)`);
}

main();
