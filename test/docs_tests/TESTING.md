**Testing Guide**

**TL;DR**
```bash
npm test
npm run coverage
```

**Contents**
1. Requirements
2. Test Commands
3. Coverage
4. Test Structure
5. Troubleshooting

**Requirements**
1. `node >= 22.10`
2. Installed dependencies: `npm i`

**Test Commands**
1. Run all tests:
```bash
npm test
```
2. Run one file:
```bash
npx hardhat test test/dex/Router.fully.ts
```
3. Run by grep:
```bash
npx hardhat test --grep "flash swap"
```

**Coverage**
1. Generate report:
```bash
npm run coverage
```
2. Target for this project: `>95%`
3. Review HTML report in `coverage/`

**Test Structure**
1. `test/dex/` full protocol suites by module
2. `test/helpers/` shared fixtures and deploy helpers
3. Mock contracts under `contracts/dex/mocks/`

**Troubleshooting**
1. If tests fail after chain reset, rerun with fresh deploy fixtures
2. If artifacts mismatch, run `npx hardhat clean && npx hardhat compile`
3. Use in-process network by default; `hardhat node` is optional for tests
