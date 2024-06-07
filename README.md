# ZodiakLottery Smart Contract

## Overview
ZodiakLottery is a decentralized lottery system built on Ethereum, integrating Chainlink VRF (Verifiable Random Function) to ensure fairness. The system uses NFTs (ZodiakNFT) to represent lottery tickets, winning tickets, and various prize tiers. This README provides an overview of the smart contract functionality, deployment instructions, and usage guidelines.

## Features
- **Lottery Pools**: Time-bound pools where users can buy tickets and win prizes.
- **Chainlink VRF Integration**: Ensures randomness of lottery outcomes.
- **NFT Tickets**: Uses ZodiakNFTs for lottery tickets, winning tickets, and prize tickets.
- **Automated Pool Management**: Pools are automatically tallied and closed after specific durations.
- **Chainlink Keepers**: Automation for tallying and closing pools is handled by Chainlink Keepers to ensure smooth and timely operations.
- **Dynamic Prize Distribution**: Different prize tiers with dynamic prize amounts.

## Contracts

### ZodiakLottery

#### State Variables
- **ZDK**: Instance of the ZodiakNFT contract.
- **COSMIC_VAULT**: Instance of the CosmicVault contract.
- **theMighty**: Address of the contract creator/administrator.
- **ticketPrice**: Price of a lottery ticket (0.01 ETH).
- **reserve**: Reserve balance for the lottery.
- **allPoolDuration**: Duration of each pool (600 seconds).
- **claimPeriodDuration**: Duration for claiming prizes after a pool ends (600 seconds).
- **lotteryPools**: Array of all lottery pools.
- **playingQueue**: Queue for managing active pools.
- **claimingQueue**: Queue for managing pools in the claiming period.
- **isOverseer**: Mapping to track overseers.
- **requests**: Mapping of VRF requests.
- **userWinningTicketsCount**: Mapping to track winning tickets per user per pool.

#### Structs

- **Pool**: Represents a lottery pool.
  - **poolId**: ID of the pool.
  - **startTimestamp**: Start time of the pool.
  - **endTimestamp**: End time of the pool.
  - **numOfPlays**: Number of plays in the pool.
  - **pot**: Total amount of money in the pool.
  - **remainingPot**: Amount of money left in the pool.
  - **numberOfWinningTickets**: Number of winning tickets in the pool.
  - **tierPot**: Prize amounts for each tier.
  - **winningTicketsRemaining**: Number of winning tickets remaining for each prize tier.
  - **prizeAmount_4_5**: Amount of prize 4 and 5 each prize ticket will get.
  - **unusedPrizeTickets**: Number of prize tickets not claimed.
  - **tallied**: Indicates if the pool has been tallied.
  - **distributed**: Indicates if the pool has been distributed.

- **RequestVRF**: Represents a request to the VRF Coordinator.
  - **zodiakChoice**: Zodiac booster choice in case of loss.
  - **poolId**: ID of the pool.
  - **isSpin**: Indicates if the request is to spin the wheel.
  - **fulfilled**: Indicates if the request has been fulfilled.
  - **requester**: Address of the user who made the request.

#### Errors

- **IncorrectAmount**: Thrown when the amount sent is incorrect.
- **InvalidId**: Thrown when an invalid ID is used.
- **CannotTallyPool**: Thrown when unable to tally the pool.
- **NoWinningTickets**: Thrown when there are no winning tickets.
- **CannotSkimPool**: Thrown when unable to skim the pool.
- **CannotSpinTheWheel**: Thrown when unable to spin the wheel.
- **InsufficientBalance**: Thrown when the balance is insufficient.
- **CannotCreateNewPool**: Thrown when unable to create a new pool.
- **RequestAlreadyFulfilled**: Thrown when a request is already fulfilled.
- **ClaimPeriodEnded**: Thrown when the claim period has ended.
- **TransferFailed**: Thrown when a transfer fails.
- **QueueIsEmpty**: Thrown when the queue is empty.

#### Events

- **PoolTallied**: Emitted when a pool is tallied.
- **PrizeClaimed**: Emitted when a prize is claimed in a pool.
- **LotteryTicketCreated**: Emitted when a lottery ticket is created.
- **WheelSpinned**: Emitted when the wheel is spun.
- **RequestFulfilled**: Emitted when a VRF request is fulfilled.
- **PoolCreated**: Emitted when a new pool is created.

#### Modifiers

- **cosmicAuthority**: Restricts function calls to overseers, theMighty, or the contract itself.

### ZodiakNFT

#### State Variables
- **theMighty**: Address of the contract creator/administrator.
- **cosmicLottery**: Address of the lottery contract.
- **maxCollections**: Maximum number of collections (18).
- **maxZodiaks**: Maximum number of zodiac signs (12).
- **zodiakBonuses**: Mapping of zodiac bonuses.

#### Structs

- **Zodiak**: Represents a zodiac's attributes.
  - **strength**: Strength attribute.
  - **agility**: Agility attribute.
  - **intelligence**: Intelligence attribute.
  - **vitality**: Vitality attribute.
  - **luck**: Luck attribute.

#### Modifiers

- **cosmicAuthority**: Restricts function calls to the lottery contract or theMighty.

### CosmicVault

#### State Variables
- **vaulting**: Tracks the amount of funds in the vault.

#### Functions

- **receive**: Handles the reception of ETH into the vault.
- **fallback**: Handles fallback reception of ETH into the vault.

## Deployment



#### ZodiakLottery
## Deployment Details

For deployment, the following parameters are required:

- **Sepolia VRF Coordinator Address**
- **Chainlink Subscription ID**
- **Keyhash**
- **Administrator Address (theMighty)**
- **URI for NFT Metadata**


 Ensure both contracts are properly linked by setting the NFT contract address in the lottery contract.

## How the Lottery System Works

### Ticket IDs

- **Wheel Ticket**: ID 0
- **Zodiac Sign - Bonus Ticket**: ID 1 - 12
- **Winning Undistributed Ticket**: ID 13

### Prize Tiers

- **Prize 1**: ID 14
- **Prize 2**: ID 15
- **Prize 3**: ID 16
- **Prize 4**: ID 17
- **Prize 5**: ID 18

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