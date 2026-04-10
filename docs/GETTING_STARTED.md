# FlashAlliance: Getting Started

**Requirements**
1. `node >= 22.10`
2. `npm`

**Install**
```bash
cd contracts/FlashAlliance
npm i
```

**Compile**
```bash
npx hardhat compile
```

**Run Tests**
```bash
npx hardhat test
```

**Run One Suite**
```bash
npx hardhat test test/FlashAlliance.ts
```

**Local Node**
```bash
npx hardhat node
```

**Deploy (Localhost)**
```bash
TOKEN_OWNER=0xYourTokenOwner \
npx hardhat run scripts/deploy/deploy-alliance.ts --network localhost
```

See deployment details in `../scripts/docs_deploy/DEPLOY.md`.
