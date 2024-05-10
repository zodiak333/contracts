// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error InvalidId(uint256 id);

/// @title Zodiak33 Marketplace
/// @author Saad Igueninni
/// @notice Listing/buying of ZodiakTickets : 
/// @dev All function calls are currently implemented without side effects

contract ZodiakMarketplace is ERC1155Holder, ReentrancyGuard {
    using Counters for Counters.Counter;

    //Stats
    Counters.Counter private _nbListedCounter;
    Counters.Counter private _nbSoldCounter;

    address private theMighty; // The creator and administrator of the contract

    IERC1155 private zodiakNFT; // ZodiakNFT contract address
    uint256 private cosmicCouncilFee = 250; //CosmicConcilFee --> To be discussed with the team

    // Only theMighty can call this function
    modifier onlyTheMighty() {
        require(
            msg.sender == theMighty,
            "Only the mighty can call this function"
        );
        _;
    }

    struct ZodiakMarketItem {
        uint256 listingTokenId; // sell order number
        uint256 nftId;          // to check with @Scott
        uint256 amount;         // amount to sell
        uint256 price;          // Price per ticket/price of the group?
        uint256 royalty;
        // uint256 nbSellsCounter;// Counter to track number of sales but how to deal with amount...
        address payable seller;
        address payable owner;
        bool paused;
        bool sold;
    }

    mapping(uint256 => ZodiakMarketItem) private marketItem; //keep track of all listed ZodiakMarketItem indexed by an icremental id ; mapping or array?

    constructor(address _zodiakNFT, address _theMighty) {
        zodiakNFT = IERC1155(_zodiakNFT);
        theMighty = _theMighty;
    }

    /// @notice It will list the NFT to marketplace.
    /// @dev It will list NFT minted from MFTMint contract.
    function listNft(
        uint256 nftId,
        uint256 amount,
        uint256 price,
        uint256 royalty
    ) external {
        if (nftId > 13) {
            revert InvalidId(nftId); //"Token does not exist"
        }

        require(royalty >= 0, "royalty should be between 0 to xxx"); //To be discussed with the team and then put as an Error
        require(royalty < 299, "royalty should be less than xxx "); //To be discussed with the team and then put as an Error

        _nbListedCounter.increment();
        uint256 listingTokenId = _nbListedCounter.current();
        // uint256 nbSellsCounter = 0;

        marketItem[listingTokenId] = ZodiakMarketItem(
            listingTokenId,
            nftId,
            amount,
            price,
            royalty,
            //   nbSellsCounter,
            payable(msg.sender),
            payable(msg.sender),
            false,
            false
        );


        // TODO --> Emit event 'Listed'
    }

    /// @notice  Buy the NFT from marketplace.
    /// @dev User will able to buy NFT and transfer to respectively owner or user and platform fees,
    /// royalty fees also deducted

    function buyNFT(uint256 listingTokenId) external payable nonReentrant {

        require(
            msg.value == marketItem[listingTokenId].price,
            "Not enough money to buy"
        );

        uint256 price = marketItem[listingTokenId].price;
        uint256 royaltyFee = (price * marketItem[listingTokenId].royalty) / 10000;
        uint256 zodiacMarketFee = (price * cosmicCouncilFee) / 10000;
        uint256 amountToSendToSeller = price - royaltyFee - zodiacMarketFee;

        // Update marketItem array
        marketItem[listingTokenId].sold = true;
        marketItem[listingTokenId].owner = payable(msg.sender);
        _nbSoldCounter.increment();

        //Transfer ERC1155 tickets to buyer
        zodiakNFT.safeTransferFrom(
            marketItem[listingTokenId].owner,
            msg.sender,
            marketItem[listingTokenId].nftId,
            marketItem[listingTokenId].amount,
            ""
        );

        // TODO -->  calculate Royalties
        // check if resale then pay royalties? only to first seller? or 1 time to last seller?
        //Transfer cosmicCouncilFee to where? this contract? another global wallet?
        //Transfer royalties to who?       

        // TODO -->  calculate cosmicCouncilFee 
        //Transfer cosmicCouncilFee to where? this contract? another global wallet?


        // TODO -->  send money to seller --> amountToSendToSeller


        // TODO -->  Emit event 'Buyed'
    }

    function fetchListedItems()  internal  {
        // keep tracking in mapping or array to make it possibke to fetch?
         // TODO -->  loop excluding Paused and sold ones
       
    }

    function cancelSell(uint256 listingTokenId) external {
        marketItem[listingTokenId].paused = true;
        // emit ItemSellCanceled(listingTokenId,msg.sender);
    }

        function pauseSell(uint256 listingTokenId) external {
            // TODO -->  pause sell by updating 'Paused' attribute
        // emit ItemSellPaused(listingTokenId,msg.sender);
    }

    /// @notice  CosmicCouncilFee getter
    function setCosmicCouncilFee(uint256 _cosmicCouncilFee) public {
        cosmicCouncilFee = _cosmicCouncilFee;
    }

    /// @notice  CosmicCouncilFee setter
    function getCosmicCouncilFee() public view onlyTheMighty returns (uint256) {
        return cosmicCouncilFee;
    }
}
