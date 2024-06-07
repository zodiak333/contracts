# ZodiakLottery Smart Contract

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Contracts](#contracts)
  - [ZodiakLottery](#zodiaklottery)
    - [State Variables](#state-variables)
    - [Structs](#structs)
    - [Errors](#errors)
    - [Events](#events)
    - [Modifiers](#modifiers)
  - [ZodiakNFT](#zodiaknft)
    - [State Variables](#zodiaknft-state-variables)
    - [Structs](#zodiaknft-structs)
    - [Modifiers](#zodiaknft-modifiers)
  - [CosmicVault](#cosmicvault)
    - [State Variables](#cosmicvault-state-variables)
    - [Functions](#cosmicvault-functions)
- [Deployment](#deployment)
  - [ZodiakLottery Deployment](#zodiaklottery-deployment)
  - [Chainlink Parameters](#chainlink-parameters)
- [How the Lottery System Works](#how-the-lottery-system-works)
  - [Ticket IDs](#ticket-ids)
  - [Prize Tiers](#prize-tiers)
- [User Interaction Flow](#user-interaction-flow)
  - [Buying Tickets](#buying-tickets)
  - [Spinning the Wheel](#spinning-the-wheel)
  - [Claiming Prizes](#claiming-prizes)
- [Admin Interaction Flow](#admin-interaction-flow)
  - [Setting Overseers](#setting-overseers)
  - [Creating a New Pool](#creating-a-new-pool)
  - [Modifying Pool Duration](#modifying-pool-duration)
  - [Tallying Pools](#tallying-pools)
  - [Closing Pools](#closing-pools)
- [Detailed Lottery Mechanics](#detailed-lottery-mechanics)
  - [Winning vs. Losing Tickets](#winning-vs-losing-tickets)
  - [Prize Tickets](#prize-tickets)de
  - [Prize Distribution](#prize-distribution)
- [Chainlink VRF and Keepers](#chainlink-vrf-and-keepers)
- [Function Reference](#function-reference)
  - [User Functions](#user-functions)
  - [Chainlink VRF Functions](#chainlink-vrf-functions)
  - [Chainlink Keeper Functions](#chainlink-keeper-functions)
  - [Admin Functions](#admin-functions)

---

## Overview
ZodiakLottery is a decentralized lottery system built for EVM compatible chains, utilizing Chainlink's Verifiable Random Function (VRF) to ensure fairness and randomness. The system employs NFTs, called ZodiakNFTs, for unrevealed tickets, winning/losing tickets, and prize tickets. This README provides a detailed guide on the smart contract functionalities.

## Features
- **Lottery Pools**: Time-bound lottery pools where participants can purchase tickets and win prizes.
- **Chainlink VRF Integration**: Ensures the randomness and fairness of lottery outcomes.
- **NFT-Based Tickets**: Utilizes ZodiakNFTs to manage lottery tickets, winners, and prize tiers.
- **Automated Pool Management**: Pools are automatically tallied and closed after specific durations.
- **Chainlink Keepers**: Automate the tallying and closing processes to ensure smooth operations.
- **Dynamic Prize Distribution**: Implements multiple prize tiers with dynamically calculated prize amounts.

## Contracts

### ZodiakLottery

#### State Variables
- **ZDK**: `ZodiakNFT` contract instance for managing NFTs.
- **COSMIC_VAULT**: `CosmicVault` contract instance for handling lottery funds.
- **theMighty**: Address of the contract's administrator.
- **ticketPrice**: Price for each lottery ticket, set at 0.01 ETH.
- **reserve**: Reserve balance for operational liquidity.
- **allPoolDuration**: Default duration for each lottery pool (600 seconds).
- **claimPeriodDuration**: Period allowed for claiming prizes after a pool closes (600 seconds).
- **lotteryPools**: Array containing all lottery pools.
- **playingQueue**: Queue managing active lottery pools.
- **claimingQueue**: Queue managing pools in the claiming period.
- **isOverseer**: Mapping of addresses authorized as overseers.
- **requests**: Mapping of VRF requests.
- **userWinningTicketsCount**: Mapping to track the count of winning tickets per user per pool.

#### Structs
- **Pool**: Defines the structure of a lottery pool.
  - **poolId**: Unique identifier for the pool.
  - **startTimestamp**: Start time of the pool.
  - **endTimestamp**: End time of the pool.
  - **numOfPlays**: Total plays in the pool.
  - **pot**: Total ETH accumulated in the pool.
  - **remainingPot**: Remaining ETH after prize distribution.
  - **numberOfWinningTickets**: Number of winning tickets in the pool.
  - **tierPot**: Distribution of prize amounts across different tiers.
  - **winningTicketsRemaining**: Count of unclaimed winning tickets.
  - **prizeAmount_4_5**: Prize amount for the 4th and 5th tier prizes.
  - **unusedPrizeTickets**: Count of unclaimed prize tickets.
  - **tallied**: Indicates if the pool has been tallied.
  - **distributed**: Indicates if the pool's prizes have been distributed.

- **RequestVRF**: Details of a VRF request to Chainlink.
  - **zodiakChoice**: Chosen Zodiac booster in case of a loss.
  - **poolId**: Identifier of the pool associated with the request.
  - **isSpin**: Indicates if the request is to spin the wheel.
  - **fulfilled**: Status of request fulfillment.
  - **requester**: Address of the user who made the request.

#### Errors
- **IncorrectAmount**: Thrown when the sent amount is incorrect.
- **InvalidId**: Thrown when an invalid ID is used.
- **CannotTallyPool**: Thrown when the pool cannot be tallied.
- **NoWinningTickets**: Thrown when no winning tickets are available.
- **CannotSkimPool**: Thrown when unclaimed funds cannot be recovered.
- **CannotSpinTheWheel**: Thrown when the wheel spin fails.
- **InsufficientBalance**: Thrown when the contract balance is insufficient.
- **CannotCreateNewPool**: Thrown when creating a new pool fails.
- **RequestAlreadyFulfilled**: Thrown when a request has already been fulfilled.
- **ClaimPeriodEnded**: Thrown when the prize claim period has ended.
- **TransferFailed**: Thrown when an ETH transfer operation fails.
- **QueueIsEmpty**: Thrown when attempting to access an empty queue.

#### Events
- **PoolTallied**: Emitted when a pool is successfully tallied.
- **PrizeClaimed**: Emitted when a prize is claimed.
- **LotteryTicketCreated**: Emitted when a new lottery ticket is generated.
- **WheelSpinned**: Emitted when the wheel is spun.
- **RequestFulfilled**: Emitted when a Chainlink VRF request is fulfilled.
- **PoolCreated**: Emitted when a new pool is created.

#### Modifiers
- **cosmicAuthority**: Restricts function calls to authorized overseers, the contract administrator (theMighty), or the contract itself.

### ZodiakNFT

#### State Variables
- **theMighty**: Address of the contract creator/administrator.
- **cosmicLottery**: Address of the linked lottery contract.
- **maxCollections**: Maximum number of NFT collections (set to 18).
- **maxZodiaks**: Maximum number of zodiac signs (set to 12).
- **zodiakBonuses**: Mapping that stores bonuses for each zodiac sign.

#### Structs
- **Zodiak**: Represents the attributes of a zodiac.
  - **strength**: Strength attribute of the zodiac.
  - **agility**: Agility attribute of the zodiac.
  - **intelligence**: Intelligence attribute of the zodiac.
  - **vitality**: Vitality attribute of the zodiac.
  - **luck**: Luck attribute of the zodiac.

#### Modifiers
- **cosmicAuthority**: Restricts function calls to either the lottery contract or theMighty.

### CosmicVault

#### State Variables
- **vaulting**: Tracks the amount of ETH in the vault.

#### Functions
- **receive**: Handles the reception of ETH into the vault.
- **fallback**: Handles fallback reception of ETH into the vault.

## Deployment

### ZodiakLottery Deployment

To deploy the ZodiakLottery contract, follow these steps:

1. **Deploy ZodiakNFT Contract**:
   - Deploy the `ZodiakNFT` contract first.
   - Note the deployed contract address.

2. **Deploy CosmicVault Contract**:
   - Deploy the `CosmicVault` contract to handle ETH.
   - Note the deployed contract address.

3. **Deploy ZodiakLottery Contract**:
   - Deploy the `ZodiakLottery` contract with the following parameters:
     - `Sepolia VRF Coordinator Address`: The address of the Chainlink VRF Coordinator for the Sepolia test network.
     - `Chainlink Subscription ID`: Your subscription ID for Chainlink VRF.
     - `Keyhash`: The keyhash provided by Chainlink for VRF requests.
     - `Administrator Address (theMighty)`: The address that will act as the administrator.
     - `ZodiakNFT Contract Address`: The address of the deployed `ZodiakNFT` contract.
     - `CosmicVault Contract Address`: The address of the deployed `CosmicVault` contract.
     - `URI for NFT Metadata`: Base URI for ZodiakNFT metadata.

4. **Link Contracts**:
   - Set the `ZodiakNFT` contract address in the `ZodiakLottery` contract to enable integration.

### Chainlink Parameters

To properly integrate Chainlink VRF and Keepers, set the following parameters manually during deployment and configuration:

#### Chainlink VRF Parameters
- **VRF Coordinator Address**:
  - The address of the Chainlink VRF Coordinator specific to your network (e.g., Sepolia).
  - For Sepolia: `0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625`

- **Subscription ID**:
  - Your Chainlink subscription ID used to fund the VRF requests.
  - Obtain this from your Chainlink account.

- **Keyhash**:
  - A unique identifier for the VRF key pair you will be using.
  - This is provided by Chainlink and ensures your contract gets the correct random values.

- **Link Token**:
  - Ensure your contract has sufficient LINK to pay for the VRF requests.
  - Fund your subscription with enough LINK tokens to cover VRF fees.

#### Chainlink Keepers Parameters
- **Keeper Registry Address**:
  - The address of the Chainlink Keeper Registry specific to your network.
  - For Sepolia: `0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad`

- **Keepers Subscription ID**:
  - Your Chainlink Keepers subscription ID to automate your contract’s functions.
  - Obtain this from your Chainlink account.

- **Automation Parameters**:
  - Configure the interval and functions that the Keepers will automate, such as pool tallying and closing.

## How the Lottery System Works

### Ticket IDs
- **Wheel Ticket**: ID 0 - Represents a generic lottery ticket used for spins.
- **Zodiac Sign - Bonus Ticket**: IDs 1 to 12 - Represents different zodiac sign boosters.
- **Winning Undistributed Ticket**: ID 13 - Represents a ticket that has won but the prize is yet to be revealed.

### Prize Tiers
- **Prize 1**: ID 14 - Highest tier prize.
- **Prize 2**: ID 15
- **Prize 3**: ID 16
- **Prize 4**: ID 17
- **Prize 5**: ID 18 - Lowest tier prize.

### User Interaction Flow

#### Buying Tickets

Users buy lottery tickets by calling the `createTicket` function and sending the appropriate amount of ETH (0.01 ETH per ticket).

**Function**: `createTicket(uint256 _amount)`
- **Parameters**:
  - `_amount`: Number of tickets to create.
  - **ETH Value**: `_amount * 0.01 ether`.

#### Spinning the Wheel

Users can spin the wheel for a chance to win a prize using their tickets by calling the `launchSpin` function.

**Function**: `launchSpin(uint256 _zodiakChoice, uint256 _poolId)`
- **Parameters**:
  - `_zodiakChoice`: ID of the zodiac booster in case of loss (Valid IDs: 1-12 for Zodiac Signs).
  - `_poolId`: ID of the pool in which the wheel is spun.

The result of the spin determines whether the user wins or loses:

- If the user wins, their ticket (ID 0) is transformed into a Winning Undistributed Ticket (ID 13).
- If the user loses, their ticket is transformed into the chosen zodiac booster (IDs 1-12).

#### Claiming Prizes

Winning ticket holders can reveal and claim their prizes by calling the `launchReveal` function.

**Function**: `launchReveal(uint256 _poolId)`
- **Parameters**:
  - `_poolId`: ID of the pool from which to reveal the prize ticket.

During the reveal process:

- The system uses Chainlink VRF to determine the prize tier.
- The Winning Undistributed Ticket (ID 13) is transformed into one of the prize tickets:
  - Prize 1: ID 14.
  - Prize 2: ID 15.
  - Prize 3: ID 16.
  - Prize 4: ID 17.
  - Prize 5: ID 18.

### Admin Interaction Flow

#### Setting Overseers

Admin can set overseer addresses to manage the lottery system by calling the `setOverseers` function.

**Function**: `setOverseers(address[] memory _overseers)`
- **Parameters**:
  - `_overseers`: Array of overseer addresses.

#### Creating a New Pool

Admin creates a new lottery pool by calling the `createPool` function.

**Function**: `createPool()`
- **Returns**: `uint256` - ID of the new pool.

#### Modifying Pool Duration

Admin modifies the duration for all pools by calling the `modifyAllPoolDuration` function.

**Function**: `modifyAllPoolDuration(uint256 _newDuration)`
- **Parameters**:
  - `_newDuration`: New duration for all pools.

#### Tallying Pools

Admin or overseer tallies the pools that have ended to determine winners by calling the `upkeepTallyPool` function.

**Function**: `upkeepTallyPool()`

#### Closing Pools

Admin or overseer closes pools after the claim period ends by calling the `upkeepClosePool` function.

**Function**: `upkeepClosePool()`

## Detailed Lottery Mechanics

### Winning vs. Losing Tickets

- **Winning Tickets**: When the wheel is spun, if the user wins, their Wheel Ticket (ID 0) is transformed into a Winning Undistributed Ticket (ID 13).
- **Losing Tickets**: When the wheel is spun and the user loses, the Wheel Ticket (ID 0) is transformed into the user's chosen zodiac booster (IDs 1-12).

### Prize Tickets

When a user with a Winning Undistributed Ticket (ID 13) reveals their prize by calling `launchReveal`:

**Function**: `launchReveal(uint256 _poolId)`
- **Parameters**:
  - `_poolId`: ID of the pool from which to reveal the prize ticket.

The reveal process uses Chainlink VRF to determine which prize the user wins. The prize tiers are as follows:

- **Prize 1**: ID 14.
- **Prize 2**: ID 15.
- **Prize 3**: ID 16.
- **Prize 4**: ID 17.
- **Prize 5**: ID 18.

The prize amounts are dynamically calculated based on the pool's pot and the number of winning tickets. Once the prize is determined, the Winning Undistributed Ticket (ID 13) is transformed into the corresponding prize ticket.

### Prize Distribution

- Prize tiers and amounts are dynamically calculated when a pool is tallied.
- The pool's pot is distributed among various prize tiers after deducting a fee.

### Chainlink VRF and Keepers

- **Chainlink VRF**: Ensures randomness in the lottery outcomes.
- **Chainlink Keepers**: Automate the tallying and closing of pools, providing reliable and timely operations without manual intervention.

## Function Reference

### User Functions

- **createTicket(_amount)**: Create new lottery tickets.
  - **_amount**: Number of tickets to create (max 10 per call).
- **launchSpin(_zodiakChoice, _poolId)**: Spin the wheel using a ticket.
  - **_zodiakChoice**: Zodiac booster ID to receive if losing.
  - **_poolId**: Pool ID to spin within.
- **launchReveal(_poolId)**: Reveal and claim prizes.
  - **_poolId**: Pool ID from which to reveal the prize ticket.

### Chainlink VRF Functions

- **spinTheWheel() [RNG]**: Determine win/loss outcome using randomness.
- **revealPrize() [RNG]**: Determine prize tier using randomness.
- **fulfilRandomWord() [RNG]**: Process the random word from Chainlink VRF.

### Chainlink Keeper Functions

- **createPool() [AUTO]**: Automatically create a new lottery pool.
- **skimPool(_poolId) [AUTO]**: Recover unclaimed funds from a closed pool.
- **tallyPool() [AUTO]**: Calculate prize distribution after the lottery ends.

### Admin Functions

- **setOverseers(address[] memory _overseers)**: Set addresses authorized to manage the lottery.
- **modifyAllPoolDuration(uint256 _newDuration)**: Modify the duration of all pools.
- **upkeepTallyPool()**: Tally the results of ended pools.
- **upkeepClosePool()**: Close pools after the claim period ends.
- **setPrice(uint256 _price)**: Set the price of a lottery ticket.
- **fulfillRandomWord() [RNG]**: Handle the random word received from Chainlink.

- 
