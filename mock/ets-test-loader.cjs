const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
// Use the installed DevEco compiler, without copying native implementation into tests.
const devEco = process.env.DEVECO_PATH || 'E:/DevEco Studio';
const compiler = process.env.TS_COMPILER_PATH || path.join(devEco, 'tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js');
if (!fs.existsSync(compiler)) throw new Error('Install DevEco Studio or set TS_COMPILER_PATH to its TypeScript compiler.');
const ts = require(compiler);
const root = path.resolve(__dirname, '../entry/src/main/ets');
function loadEts(entry, overrides = {}) {
  const cache = new Map();
  function load(file) {
    file = path.resolve(file); if (!file.startsWith(root + path.sep)) throw new Error('Test import outside ArkTS source');
    if (cache.has(file)) return cache.get(file).exports;
    const source = fs.readFileSync(file, 'utf8');
    const result = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS, experimentalDecorators: true }, fileName: file });
    const module = { exports: {} }; cache.set(file, module);
    const context = { module, exports: module.exports, console, ObservedV2: klass => klass, Trace: () => {},
      require: name => Object.hasOwn(overrides, name) ? overrides[name] : load(path.resolve(path.dirname(file), name + '.ets')) };
    vm.runInNewContext(result.outputText, context, { filename: file }); return module.exports;
  }
  return load(path.join(root, entry));
}
module.exports = { loadEts };
