const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { execFileSync } = require('child_process');

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].substring(2);
      const val = (i + 1 < args.length && !args[i + 1].startsWith('--')) ? args[++i] : true;
      options[key] = val;
    }
  }
  return options;
}

function resolveAsarModule(customPath) {
  const candidates = [
    customPath,
    path.resolve(__dirname, '../payload/localization/node_modules/@electron/asar'),
    path.resolve(__dirname, '../../work/ag-deps/node_modules/@electron/asar'),
    path.resolve(__dirname, '../../work/ag-chinese/node_modules/@electron/asar'),
    '@electron/asar'
  ].filter(Boolean);

  for (const c of candidates) {
    try {
      return require(c);
    } catch (_) {}
  }
  throw new Error('Cannot find @electron/asar module in candidates');
}

function normalizeName(f) {
  return path.normalize(f.replace(/^[/\\]+/, ''));
}

async function checkAsar(asar, asarPath) {
  if (!fs.existsSync(asarPath)) {
    return { exists: false, error: 'ASAR file does not exist' };
  }
  const files = asar.listPackage(asarPath).map(normalizeName);
  let version = 'unknown';
  try {
    const pkg = JSON.parse(asar.extractFile(asarPath, 'package.json').toString('utf8'));
    version = pkg.version || 'unknown';
  } catch (_) {}

  let isPatched = false;
  try {
    const preload = asar.extractFile(asarPath, 'dist/preload.js').toString('utf8');
    isPatched = preload.includes('Antigravity Chinese Localization Injection Start');
  } catch (_) {}

  return {
    exists: true,
    version,
    totalEntries: files.length,
    isPatched
  };
}

async function buildPatchedAsar(asar, options) {
  const originalAsar = options.originalAsar;
  const chineseTool = options.chineseTool || path.resolve(__dirname, '../payload/localization/cli.js');
  const destAsar = options.destAsar;
  const tempDir = options.tempDir || path.resolve(__dirname, '../temp-staging');

  if (!fs.existsSync(originalAsar)) throw new Error('Original ASAR not found: ' + originalAsar);
  if (!fs.existsSync(chineseTool)) throw new Error('Chinese localization tool not found: ' + chineseTool);

  // 准备隔离工作目录
  fs.rmSync(tempDir, { recursive: true, force: true });
  const stagingAsarDir = path.join(tempDir, 'resources');
  const stagingUnpacked = path.join(tempDir, 'unpacked');
  fs.mkdirSync(stagingAsarDir, { recursive: true });
  fs.mkdirSync(stagingUnpacked, { recursive: true });

  const stagingAsar = path.join(stagingAsarDir, 'app.asar');
  fs.copyFileSync(originalAsar, stagingAsar);

  // 如果原始安装目录有 app.asar.unpacked，也链接或复制到临时目录供汉化工具检查
  const originalUnpacked = originalAsar + '.unpacked';
  if (fs.existsSync(originalUnpacked)) {
    const stagingExt = stagingAsar + '.unpacked';
    try {
      fs.symlinkSync(originalUnpacked, stagingExt, 'junction');
    } catch (_) {
      fs.cpSync(originalUnpacked, stagingExt, { recursive: true });
    }
  }

  // 执行汉化工具提取差异文件
  execFileSync(process.execPath, [chineseTool, 'install', '--path', stagingAsar], {
    stdio: 'pipe',
    env: { ...process.env, NODE_ENV: 'production' }
  });

  const files = asar.listPackage(originalAsar).map(normalizeName);
  asar.extractAll(originalAsar, stagingUnpacked);

  const changed = [];
  for (const f of files) {
    const s = asar.statFile(originalAsar, f);
    if (s.files || s.link) continue;
    const before = asar.extractFile(originalAsar, f);
    const after = asar.extractFile(stagingAsar, f);
    if (!before.equals(after)) {
      if (!/^dist[\\/].+\.js$/.test(f)) {
        throw new Error(`Unexpected changed file from patch: ${f}`);
      }
      // 语法验证
      new vm.Script(after.toString('utf8'), { filename: f });
      fs.writeFileSync(path.join(stagingUnpacked, f), after);
      changed.push(f);
    }
  }

  if (!changed.some(f => f.endsWith('preload.js'))) {
    throw new Error('Critical preload.js patch was not generated');
  }

  // 严格保留 chrome-devtools-mcp 外置打包规则
  fs.mkdirSync(path.dirname(destAsar), { recursive: true });
  await asar.createPackageWithOptions(stagingUnpacked, destAsar, {
    unpack: '**/chrome-devtools-mcp/**'
  });

  // 结构与外置一致性双重校验
  if (asar.listPackage(destAsar).length !== files.length) {
    throw new Error('Built ASAR entry count does not match original');
  }

  let externalCount = 0;
  for (const f of files) {
    const a = asar.statFile(originalAsar, f);
    const b = asar.statFile(destAsar, f);
    if (a.files || a.link) continue;
    if (!!a.unpacked !== !!b.unpacked) {
      throw new Error(`External unpack flag mismatch on: ${f}`);
    }
    if (a.unpacked) externalCount++;
    if (!asar.extractFile(stagingAsar, f).equals(asar.extractFile(destAsar, f))) {
      throw new Error(`Content mismatch on: ${f}`);
    }
  }

  return {
    success: true,
    destAsar,
    changedFiles: changed,
    totalEntries: files.length,
    externalEntries: externalCount,
    syntaxPassed: true
  };
}

(async () => {
  const options = parseArgs();
  const asar = resolveAsarModule(options.asarModule);
  const action = options.action || 'check';

  let result;
  if (action === 'check') {
    result = await checkAsar(asar, options.asarPath);
  } else if (action === 'build') {
    result = await buildPatchedAsar(asar, options);
  } else {
    throw new Error('Unknown action: ' + action);
  }

  console.log(JSON.stringify(result, null, 2));
})().catch(err => {
  console.error(JSON.stringify({ success: false, error: err.message, stack: err.stack }));
  process.exit(1);
});
