# beaaam

  
<h1 align="center">
  <br>
  <a href=""><img src="https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjt_SSkFvJjbtmUL5c-II8P8u0bsBmwx8-vCpVV64iHxP8CEL2eAGoY9cP7EQ_nZGIxRJbVOB-X1GBnkJjdNj-DzHVff9mdHNUGpNGM4AM-4E_mrliU3gF8GSycafmYzQ8yR2SH5FG0bPTwR7E9C3TS8AykiUZ_IqAM8XjT4U1QhxVilh0RW788OunFfv0/s1340/beaaam.jpg" width="300"></a>
  <br>
  Beaaam
  <br>
</h1>

<h4 align="center">The Cutting-Edge Protocol for Seamless Token Beaaaming aka Streaming 😉</h4>

<p align="center">
  <a href="#Introduction">Introduction</a> •
  <a href="#key-features">Key Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#local-deployment">Local deployment</a> •
  <a href="#beaaaming-design-principle">Beaaaming Design Principle</a> •
  <a href="#beam-accounts">beam accounts </a> •
  <a href="#beam-sdk">beam sdk </a> •
  <a href="#license">License</a>
</p>

![screenshot](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjt_SSkFvJjbtmUL5c-II8P8u0bsBmwx8-vCpVV64iHxP8CEL2eAGoY9cP7EQ_nZGIxRJbVOB-X1GBnkJjdNj-DzHVff9mdHNUGpNGM4AM-4E_mrliU3gF8GSycafmYzQ8yR2SH5FG0bPTwR7E9C3TS8AykiUZ_IqAM8XjT4U1QhxVilh0RW788OunFfv0/s1340/beaaam.jpg)

## Introduction 

 Beam protocol embodies full decentralization, non-custodial autonomy, and gas optimization. It empowers you to schedule and structure ERC-20 token transactions to specific addresses. Please note that the provided information is solely for educational purposes.

Beaaaming entails gradual fund transfer over time. Initializing beaaaming involves configuring a list of receivers and funding your streamable balance. Once configured, fund flow commences automatically until the balance depletes. Balance adjustments, such as topping up or withdrawing unstreamed funds, are feasible anytime. The balance updates every second and cannot retrieve already-streamed funds. Receiver lists can be modified at any time, affecting future beaaaming behavior. Each user has distinct configurations and balances for separate ERC-20 tokens.

Receiver lists encompass 0 to 100 entries, orderly and unique. Active receivers solely receive tokens from your list. Entries comprise a receiver's user ID and beaaaming rate in tokens per second, offering precision beyond whole tokens. Optional start times and maximum durations can be attached. Future start times delay beaaaming, while durations limit it. Balance and receiver updates leverage the setStreams function of your user's driver. Balance changes necessitate concurrent receiver list updates, and vice versa, with zero balance change permitted.

Beams protocol embodies decentralized elegance, enabling structured ERC-20 token transactions

## Key Features

Key Features of Beam :

1. **Native ERC20 Beaaaming:** Beam facilitates the beaaaming of any ERC20 token without the need for wrapping, eliminating additional contracts and trust-related assumptions.

2. **Gas Efficiency for Scaling:** Beam is optimized for both one-to-one and many-to-one beaaaming scenarios, targeting real-world scales on the Ethereum mainnet while maintaining gas efficiency.

3. **Scheduled beaaams:** Users and developers can schedule streams to start and end at specific future times, enhancing precision in fund beaaaming management.

4. **Shared Stream Balances:** Unlike other protocols, Beams allows users to fund and top-up multiple streams using a single balance and transaction, reducing the number of transactions and associated gas costs.

5. **Flexible Identity Model:** Beam introduces a more versatile user identity and account model, accommodating various methods of account creation, including NFTs or Git repositories.


These enhancements in Beam  streamline the user experience while maintaining flexibility, scalability, and efficiency in managing token streams.

## Usage
the possibilities are endless. Users can effortlessly beaaam tokens to any  address, ensuring a smooth and continuous flow of funds. Whether it's distributing earnings to contributors, setting up vesting schedules, or offering subscription-based services, Ktrh's dynamic features cater to diverse business models.

## Local deployment

a. In the backend directory, run yarn to build beaaam package:

```bash
yarn
```

Use the yarn link command to link the local package. 

```bash
yarn link
```

b. Then, in the webapp directory where you want to use beaaams-backend, run:

```bash
yarn link beaaams-backend
```

after that run yarn to procced with installing all the packages 

```bash
yarn 
```

then run the local dev app

```bash
yarn dev
```

## Beaaaming Design Principle

Beams is a protocol for any EVM-based blockchain that allows users to set up and manage continuous transfers of funds from one account to another over time. We refer to such transfers as "Beaaams".
Technically, tokens that are streamed are not sent directly to the recipient's address. Instead, the [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol) contract keeps track of the sender and recipient's balances and allows the receiver to collect funds whenever they wish.

[BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol) works internally with the concept of "cycles" and all funds being sent to a given recipient for a given cycle are aggregated and stored together as a pooled amount in the [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol) smart contracts. In fact, for greater efficiency, it is not even the pooled stream amounts themselves that are stored, but rather the "deltas", or changes in amount streamed, from one cycle to the next.

### Beams Cycles

Each cycle defines a fixed time interval so that every block is assigned to exactly one cycle based on its timestamp. Cycles are indexed starting from 1 and cycle times and indexes are the same for all Beams users.

### Beaaaming funds 

Any user can stream funds to another user. The state of a sender for a specific ERC20 token can be described with the following attributes:

    - Balance - balance of tokens that the sender holds in their account.
    - Set of BeamsConfigs - configurations for Beams that the sender is beaaaming to other users (if any).

Based on the set of beaaams, a total funding rate per cycle can be derived. The balance is automatically reduced by the funding rate every second and the same amount is credited to the sender's receivers.

When the sender's balance reaches an amount lower than the per-second funding rate, the funding is stopped. This process doesn't actually require updates every second. Instead, its effects are calculated on the fly whenever they are needed. Thus the contract state is updated only when the funding parameters are altered by the users.

The sender balance is manually increased by topping up, which requires sending some ERC-20 tokens from the user's wallet to the [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol) contract. The opposite operation is withdrawal, which results in removing tokens from the contract back to the user wallet.

In order to start sending, the only requirements are that the sender has a non-zero balance and a non-empty list of receivers. As soon as the sender's configuration is updated to match these criteria, the flow of tokens starts. First, the funding period is calculated. Its start is the current block timestamp and its end is the moment on which the balance will run out (unless some streams have been scheduled as discussed above).

## beams accounts

Beams accommodates diverse account types, granting control over funds to Ethereum addresses, and  NFT-based accounts This versatility is achieved through a modular system called "account drivers," which utilize smart contracts to manage distinct account implementations. What is meant by account is as following:

    - A unique identifier that corresponds one-to-one to an account that can send and receive funds (e.g. using Beaaaming) in the Beams Protocol.
    - A way to authenticate critical actions on that account, like withdrawing funds, or setting up new beaamings.

### beams account ID 

In Beams, each user's identity is associated with an account ID—a 32-byte number that encodes two distinct "component" IDs.

The Driver ID corresponds to the Beams smart contract's driver responsible for authentication and fund management for the account.

The Driver Sub-Account ID specifies the account's unique position within the driver's range of managed IDs, distinguishing it from other accounts under that driver.

While most end-users won't need to delve into these technical intricacies, developers building on Beams may find them relevant. The key takeaway for developers is that each account ID connects to a specific driver in [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol) (which manages the ID and authorizes user access) and a designated "sub-account" within that driver's account space. This sub-account segregates funds and configurations from those of other users.

### [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol)  Account drives 

In Beams, each driver manages a range of account IDs, with the first 4 bytes of the account ID matching the driver's registration ID in [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol).

For example, consider the [AddressDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/AddressDriver.sol), registered as ID 0 in [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol). It allows Ethereum addresses to manage unique Beams accounts. This is achieved through the [setBeams(...)](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/AddressDriver.sol#L49C17-L49C17) method in AddressDriver's smart contract, which sets the message sender's Beams configuration. The callerAccountId() and calcAccountId(address userAddr) helper methods translate the sender's address into a unique account ID, used within [AddressDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/AddressDriver.sol)'s controlled range.

Similarly, the [NFTDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/NFTDriver.sol)  is a valuable tool for developers. Unlike [AddressDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/AddressDriver.sol), [NFTDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/NFTDriver.sol)  allows users to create unlimited NFT-based accounts, each with its own balance and streaming settings, specific to the app. This is done through the ERC-721 contract, which mints and burns NFT-based Beams accounts. [NFTDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/NFTDriver.sol) 's authorization methods, like onlyHolder(uint256 tokenId), ensure changes are made by NFT holders, and these calls are then relayed to [BeamsHub](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol) with the token ID as the account ID.

Both [AddressDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/AddressDriver.sol) and [NFTDriver](https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/NFTDriver.sol) showcase how Beams' extensible account model accommodates various account types. Despite the differences, they function interchangeably at the lowest protocol level, demonstrating the versatility and power of the Beams Protocol.

## beam sdk 

When utilizing the Beams JavaScript SDK, developers are shielded from the intricate nuances, thanks to convenience classes that simplify the process. These classes encapsulate much of the complexity, even managing account IDs, for common actions developers frequently need. For instance, if a developer wants to enable end-users to gather funds beaaamed to them via Beams, they can effortlessly accomplish this by creating an [AddressDriverClient](https://github.com/malawadd/beaaam/blob/main/backend/src/AddressDriver/AddressDriverClient.ts) and invoking the collect() method, whose signature appears as follows:

    public async collect(tokenAddress: string, transferToAddress: string): Promise

You'll notice that this method signature contains no mention of any account IDs - it's all just ordinary Ethereum addresses (here transferToAddress is the Ethereum address that the user wishes to collect their funds to).

## smart contracts deployments 



## License

MIT
