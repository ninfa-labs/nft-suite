# <img src="logo.webp" alt="Ninfa.io" width='267px'>

[![NINFA.io](https://img.shields.io/badge/NINFA.io-NFT%20Marketplace-white?style=for-the-badge&logo=ethereum)](https://ninfa.io)

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://docs.ninfa.io)
[![CI](https://github.com/ninfa-labs/nft-suite/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ninfa-labs/nft-suite/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/ninfa-labs/nft-suite/branch/main/graph/badge.svg)](https://codecov.io/gh/ninfa-labs/nft-suite)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)

A template library for secure NFT smart contracts development, including:

- [**NFT Marketplace**](https://docs.ninfa.io/tutorials/marketplace), create and manage on-chain NFT orders and offers, pay
  with ETH or USDC.
- [**English Auction**](https://docs.ninfa.io/tutorials/auction)
- **ERC-721** and **ERC-1155** token presets:
  - Minting ([ERC-721](https://docs.ninfa.io/tutorials/erc-721/erc721base),
    [ERC-1155](https://docs.ninfa.io/tutorials/erc-1155/erc1155base))
  - Lazy-minting ([ERC-721](https://docs.ninfa.io/tutorials/erc-721/erc721lazymint),
    [ERC-1155](https://docs.ninfa.io/tutorials/erc-1155/erc1155lazymint))
  - Generative art ([ERC-721](https://docs.ninfa.io/tutorials/erc-721/erc721generative))
  - Open editions ([ERC-1155](https://docs.ninfa.io/tutorials/erc-1155/erc1155openedition))
- **Clones "factory"**, deploy minimal proxy contracts aka "[clones](https://docs.openzeppelin.com/contracts/5.x/api/proxy#minimal_clones)", simply and cheaply in an immutable way:
  - [Curated](https://docs.ninfa.io/tutorials/factory/curatedfactory): a communal role-based access control factory,
    including a "curator" and a "minter" roles.
  - [Open](https://docs.ninfa.io/tutorials/factory/openfactory): sovereign factory with single owner, public `clone`
    function, deploy copies of contract instances whitelisted by the owner.
  - [Payable](https://docs.ninfa.io/tutorials/factory/payablefactory): sovereign factory with single owner, allowing
    anyone to clone whitelisted contracts for a fee.

## Overview

Click the [`Use this template`](https://github.com/ninfa-labs/nft-suite/generate) button at the top of the Github page
in order to create a new repository from this project.

You may also install the template directly from the terminal using Foundry,
if this is your first time with Foundry, check out the [installation](https://github.com/foundry-rs/foundry#installation) instructions:

```sh
forge init --template ninfa-labs/nft-suite my-nft-project
cd my-nft-project
bun install # install Solhint, Prettier, and other Node.js deps
```

Alternatively, if you have an existing project and just want to import the contracts as a library, install the contracts package
using your preferred Solidity development framework:

```sh
# Using Foundry
forge install ninfa-labs/nft-marketplace
# Using Hardhat
npm install ninfa-labs/nft-suite
```

## Dependencies

Foundry typically uses git submodules to manage dependencies, but this template uses Node.js packages because
[submodules don't scale](https://twitter.com/PaulRBerg/status/1736695487057531328).

This is how to install dependencies:

1. Install the dependency using your preferred package manager, e.g. `bun install dependency-name`
   - Use this syntax to install from GitHub: `bun install github:username/repo-name`
2. Add a remapping for the dependency in [remappings.txt](./remappings.txt), e.g.
   `dependency-name=node_modules/dependency-name`

The following dependencies are included in `package.json`:

- [Forge Std](https://github.com/foundry-rs/forge-std): collection of helpful contracts and cheatcodes for testing
- [Solhint](https://github.com/protofire/solhint): linter for Solidity code
- [Prettier Plugin Solidity](https://github.com/prettier-solidity/prettier-plugin-solidity): code formatter for
  non-Solidity files

Note: Any external smart contract libraries, such as [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts),
have been included in the `src` directory as part of the local codebase, i.e. there is no `lib` folder,
the original author and version are recorded within each contract's NatSpec comments.

## Sensible Defaults

This template comes with a set of sensible default configurations for you to use. These defaults can be found in the
following files:

```
├── .editorconfig
├── .gitignore
├── .prettierignore
├── .prettierrc.yml
├── .solhint.json
├── foundry.toml
└── remappings.txt
```

## GitHub Actions

This template comes with GitHub Actions pre-configured. Your contracts will be linted and tested on every push and pull
request made to the `main` branch.

You can edit the CI script in `.github/workflows/ci.yml`.

## Test Suite

To run all unit test files located in `/test`:

```bash
forge test
```

To run a specific test file and test function:

```bash
forge test --match-path test/ERC721Base.t.sol --match-test testMint -vvvv
```

Get a gas report:

```bash
forge test --gas-report
```

Custom RPC endpoing:

```bash
forge test --fork-url=${RPC_URL_MAINNET} [...]
```

## Deployment Scripts

Deployment scripts are located in the `script` folder. Currently it contains a single script, `Deploy.sol`, which can be
used to deploy all contracts on any EVM compatible chain.

```bash
forge script script/Deploy.sol [...] --broadcast
```

The `--broadcast` flag should only be used in order to deploy on the real testnet or mainnet, if the flag is omitted,
Foundry will use an RPC endpoint if provided and do a dry-run deployment, if no endpoint is provided it will deploy
on a local blockchain (Anvil).

Example using a custom RPC endpoint (local node):

```
forge script script/Deploy.s.sol --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For more instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/guides/scripting-with-solidity) tutorial.

## Deployment Flow  for Minimal Proxy Clones

The following paragraphs describe the inner workings of the factory deployment&#x20;

### 1. Deploy the Factory

Begin by deploying a **factory contract** (e.g., `OpenFactory`) that creates [**minimal clones**](https://docs.openzeppelin.com/contracts/5.x/api/proxy#minimal_clones) . This factory may manage:

* Optional cloning fees (e.g., `FEE_BPS`, `FEE_RECIPIENT`)
* Whitelisting of approved master copies
* Cloning logic to deploy a proxy using`create2` (salted deterministic deployment)
* Functions to predict the addresses of clones deployed using the deterministic method.

```solidity
address FACTORY = new OpenFactory(FEE_BPS, FEE_RECIPIENT);
```

### 2. Deploy the Master Copy

Deploy a **master copy** (an instance of `ERC721Base`), passing the factory’s address to its constructor:

```solidity
address ERC721_BASE_MASTER = new ERC721Base(address(FACTORY));
```

#### Constructor

The `constructor` of  token contracts is used to set common state needed by cloned contracts, i.e. the address of the factory contract from which clones will be created (this means a factory instance must already exist because its address is needed as a `constructor` argument by token contracts).

```solidity
constructor(address factory_) {
    _FACTORY = factory_;
}
```

* Stores the **factory contract** address.
* Ensures only that factory can invoke the clone’s initialization.

**Why a Master Copy?**

* Serves as the “implementation” contract.
* Each **clone** references this code via **delegatecall**, reducing gas versus a full deployment.

### 3. Whitelist the Master Copy

To allow the factory to clone a specific master copy, it must be **whitelisted**:

```solidity
FACTORY.setMaster(address(ERC721_BASE_MASTER), true);
```

### 4. Clone and Initialize

Once the master is whitelisted, call the factory’s `clone` function:

```solidity
address cloneAddress = FACTORY.clone(
    address(ERC721_BASE_MASTER),
    bytes32(0x0),
    abi.encode(_MINTER, 1000, _SYMBOL, _NAME)
);

ERC721Base cloneInstance = ERC721Base(cloneAddress);
```

* **`_instance`**: Address of the whitelisted master copy.
* **`_salt`**: For deterministic CREATE2 deployment or `0x0` if not needed.
* **`_data`**: Encoded parameters for `initialize(bytes)`.

After deployment, the factory calls the clone’s `initialize(_data)`, which sets roles, royalties, and metadata.

The line `require(msg.sender == _FACTORY);` is used for access control, it compares `msg.sender` with the address of the factory contract that was set at deployment of the master contract instance. Therefore, all cloned contract instances will share the same factory address, without the need to set new access control state variables such as [**Openzeppelin's initializers**](https://docs.openzeppelin.com/contracts/5.x/api/proxy#Initializable) every time a new clone is deployed.

#### Initialize Function

```solidity
function initialize(bytes memory _data) public virtual {
    require(msg.sender == _FACTORY);

    (address deployer, uint96 defaultRoyaltyBps, string memory symbol_, string memory name_) =
        abi.decode(_data, (address, uint96, string, string));
    symbol = symbol_;
    _name = name_;

    _setDefaultRoyalty(deployer, defaultRoyaltyBps);

    _grantRole(DEFAULT_ADMIN_ROLE, deployer);
    _grantRole(CURATOR_ROLE, deployer);
    _grantRole(MINTER_ROLE, deployer);
    _setRoleAdmin(MINTER_ROLE, CURATOR_ROLE);
}
```

* **Access Restriction**: Only the factory can call it (`require(msg.sender == _FACTORY)`).
* **Data Decoding**: Extracts `deployer`, `defaultRoyaltyBps`, `symbol`, `name`.
* **Role Assignment**: Grants admin, curator, and minter roles to the `deployer`.
* **Default Royalty**: `_setDefaultRoyalty(deployer, defaultRoyaltyBps)`.

## Verifying a Contract

Example command

```bash
forge verify-contract \
    --chain-id 42 \
    --num-of-optimizations 1000000 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(string,string,uint256,uint256)" "ForgeUSD" "FUSD" 18 1000000000000000000000) \
    --etherscan-api-key <your_etherscan_api_key> \
    --compiler-version v0.8.10+commit.fc410830 \
    <the_contract_address> \
    src/MyToken.sol:MyToken
```

## Preset Contracts

"Presets" are fully complete smart contracts that can be customized by overriding functions OR by importing
"[extensions](./#extending-preset-token-contracts)" contracts.

These contracts integrate different Ethereum NFT standards (ERCs) with custom extensions modules, showcasing common
configurations that are ready to deploy without having to write any Solidity code.

They can be used as-is for quick prototyping and testing, but are also suitable for production environments.

For example, `ERC721Base` is a token preset, as it contains all standard function interfaces plus some optional ones,
here is the contract declaration for the `ERC721Base` preset:

```solidity
contract ERC721Base is AccessControl, ERC721Burnable, ERC721Royalties, ERC721Metadata_URI, ERC721Enumerable {
```

In the above line, all inherited contracts besides `AccessControl` are extensions contracts, `ERC721Enumerable` inherits
from the parent `ERC721` contract and adds to it an optional extension of
[`ERC721`](https://docs.openzeppelin.com/contracts/4.x/api/token/erc721#ERC721) defined in the EIP that adds
enumerability of all the token ids in the contract as well as all token ids owned by each account and the.

### Inheriting from Presets

All of the contracts are expected to be used either standalone or via inheritance by inheriting from them when writing
your own contracts. See the tutorials section for details each contract.

Extensions provide a way for you to pick and choose which individual pieces you want to put into your contract; with
full customization of how those features work. These are available at `src/token/ERC721/extensions/` and
`src/token/ERC1155/extensions/` depending on the token standard.

Extensions are simply contracts that are meant to be inherited by implementations and their functions either called or
overridden by the child implementation. Token preset contracts are an example of how exentions should be implemented,
see `src/token/ERC721/presets` and `src/token/ERC1155/presets`.

Alternatively, users can use these as starting points when writing their own contracts, extending them with custom
functionality as they see fit.

**1.** To start, import and inherit a preset contract.

**2.** Preset contracts expect certain constructor arguments to function as intended. Implement a constructor for your
smart contract and pass the appropriate values to a constructor for the base contract. You also MAY want to override the
`initialize` function, for example the preset contract `ERC721LazyMint` inherits a library `EIP712` thus extending the
base preset contract and overrides the initialize function in order to initialize the inherited contract as well.

```solidity
contract ERC721LazyMint is ERC721Base, EIP712 {

    function initialize(bytes memory _data) public override(ERC721Base, EIP712) {
        ERC721Base.initialize(_data);
        // initialize Base contract before EIP712 because
        // "name" metadata MUST to be set prior calling EIP712's initialize()
        EIP712.initialize("");
    }

    constructor(address factory_) ERC721Base(factory_) { }
}
```

Inheritance allows you to extend your smart contract's properties to include the parent contract's attributes and
properties. The inherited functions from this parent contract can be modified in the child contract via a process known
as overriding.

### Upgradeability

All NFT preset contracts in `./src/token` are compatible with both upgradeable and regular deployment patterns. All
initial state changes are written inside the `initialize()` function, rather than the constructor, this is so that
contract specific parameters can be set when deploying new sovereign contracts (clones) from a factory contract.
Therefore, even though the clones are not really upgradeable, they have most of the same requirements that upgradeable
contracts have: initializer function, no immutable variables.

## Bug reports

Found a security issue with our smart contracts? Send bug reports to security@ninfa.io and we'll continue communicating
with you from there.

## Feedback

If you have any feedback, please reach out to us at support@ninfa.io.

## Authors

[Cosimo de' Medici](https://github.com/codemedici) @ [**Ninfa.io**](https://ninfa.io)

## License

[MIT](./LICENSE)
