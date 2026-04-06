const fs = require('node:fs/promises');
const path = require('node:path');

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function ensureDir(p) {
  await fs.mkdir(p, { recursive: true });
}

function log(logger, message) {
  if (logger && logger.log) {
    logger.log(message);
  }
}

function warn(logger, message) {
  if (logger && logger.warn) {
    logger.warn(message);
  } else {
    log(logger, message);
  }
}

function extractFrontmatter(content) {
  if (!content.startsWith('---\n')) {
    return null;
  }

  const endMarker = '\n---\n';
  const endIndex = content.indexOf(endMarker, 4);
  if (endIndex === -1) {
    return null;
  }

  return content.slice(0, endIndex + endMarker.length);
}

function buildSkillStub(frontmatter, skillName, targetPath) {
  return [
    frontmatter.trimEnd(),
    '',
    `# ${skillName}`,
    '',
    '> **This is a stub.** Load and execute the canonical skill from the release module.',
    '> All paths are relative to the workspace root.',
    '',
    '```',
    `Read and follow all instructions in: ${targetPath}`,
    '```',
    ''
  ].join('\n');
}

function buildPromptStub(frontmatter, promptName, targetPath) {
  return [
    frontmatter.trimEnd(),
    '',
    `# ${promptName} (Stub)`,
    '',
    '> **This is a stub.** Load and execute the full prompt from the release module.',
    '> All `_bmad/` paths in the full prompt are relative to the workspace root.',
    '',
    '```',
    `Read and follow all instructions in: ${targetPath}`,
    '```',
    ''
  ].join('\n');
}

async function loadFrontmatter(preferredPath, fallbackPath) {
  if (await pathExists(preferredPath)) {
    const existing = await fs.readFile(preferredPath, 'utf8');
    const existingFrontmatter = extractFrontmatter(existing);
    if (existingFrontmatter) {
      return existingFrontmatter;
    }
  }

  const fallback = await fs.readFile(fallbackPath, 'utf8');
  const fallbackFrontmatter = extractFrontmatter(fallback);
  if (!fallbackFrontmatter) {
    throw new Error(`Missing YAML frontmatter in ${fallbackPath}`);
  }
  return fallbackFrontmatter;
}

async function generateSkillStubs(projectRoot, moduleDir, logger) {
  let skillsDir = path.join(moduleDir, 'skills');
  
  // Fallback: check release directory if local directory not found
  if (!(await pathExists(skillsDir))) {
    const releaseSkillsDir = path.join(projectRoot, 'release', '_bmad', 'lens', 'skills');
    if (await pathExists(releaseSkillsDir)) {
      skillsDir = releaseSkillsDir;
    } else {
      warn(logger, `Lens installer: skills directory not found at ${skillsDir} or ${releaseSkillsDir}`);
      return 0;
    }
  }

  const githubSkillsDir = path.join(projectRoot, '.github', 'skills');
  const entries = await fs.readdir(skillsDir, { withFileTypes: true });
  let generated = 0;

  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }

    const skillName = entry.name;
    const canonicalPath = path.join(skillsDir, skillName, 'SKILL.md');
    if (!(await pathExists(canonicalPath))) {
      continue;
    }

    const stubPath = path.join(githubSkillsDir, skillName, 'SKILL.md');
    const frontmatter = await loadFrontmatter(stubPath, canonicalPath);
    const stub = buildSkillStub(frontmatter, skillName, `_bmad/lens/skills/${skillName}/SKILL.md`);

    await ensureDir(path.dirname(stubPath));
    await fs.writeFile(stubPath, stub, 'utf8');
    generated += 1;
  }

  return generated;
}

async function generatePromptStubs(projectRoot, moduleDir, logger) {
  let promptsDir = path.join(moduleDir, 'prompts');
  
  // Fallback: check release directory if local directory not found
  if (!(await pathExists(promptsDir))) {
    const releasePromptsDir = path.join(projectRoot, 'release', '_bmad', 'lens', 'prompts');
    if (await pathExists(releasePromptsDir)) {
      promptsDir = releasePromptsDir;
    } else {
      warn(logger, `Lens installer: no canonical prompts directory at ${promptsDir} or ${releasePromptsDir}; skipping prompt stubs.`);
      return 0;
    }
  }

  const githubPromptsDir = path.join(projectRoot, '.github', 'prompts');
  const entries = await fs.readdir(promptsDir, { withFileTypes: true });
  const promptFiles = entries.filter((entry) => entry.isFile() && entry.name.endsWith('.prompt.md'));

  if (promptFiles.length === 0) {
    warn(logger, `Lens installer: no canonical prompt files found in ${promptsDir}; skipping prompt stubs.`);
    return 0;
  }

  let generated = 0;
  for (const entry of promptFiles) {
    const canonicalPath = path.join(promptsDir, entry.name);
    const stubPath = path.join(githubPromptsDir, entry.name);
    const promptName = entry.name.replace(/\.prompt\.md$/, '');
    const frontmatter = await loadFrontmatter(stubPath, canonicalPath);
    const stub = buildPromptStub(frontmatter, promptName, `_bmad/lens/prompts/${entry.name}`);

    await ensureDir(path.dirname(stubPath));
    await fs.writeFile(stubPath, stub, 'utf8');
    generated += 1;
  }

  return generated;
}

async function install(options) {
  const { projectRoot, config = {}, logger } = options;

  try {
    const moduleDir = path.join(projectRoot, '_bmad', 'lens');
    await ensureDir(moduleDir);

    const targetConfig = path.join(moduleDir, 'bmadconfig.yaml');
    if (!(await pathExists(targetConfig))) {
      const content = [
        '# Lens module runtime defaults',
        '# Generated by _module-installer/installer.js',
        '',
        'module_code: lens',
        'module_name: "Lens"',
        '',
        `default_track: "${config.default_track || 'full'}"`,
        `theme: "${config.theme || 'default'}"`,
        `activation_mode: "${config.activation_mode || 'auto'}"`,
        `target_repos: "${config.target_repos || ''}"`,
        '',
      ].join('\n');
      await fs.writeFile(targetConfig, content, 'utf8');
    }

    const generatedSkillStubs = await generateSkillStubs(projectRoot, moduleDir, logger);
    const generatedPromptStubs = await generatePromptStubs(projectRoot, moduleDir, logger);

    log(logger, `Lens module files installed. Generated ${generatedSkillStubs} skill stubs and ${generatedPromptStubs} prompt stubs.`);
    log(logger, 'Run bmad-lens-setup to merge config and register help entries.');
    return true;
  } catch (error) {
    if (logger && logger.error) {
      logger.error(`Lens install failed: ${error.message}`);
    }
    return false;
  }
}

module.exports = { install };
