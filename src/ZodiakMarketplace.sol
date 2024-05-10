// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error InvalidNFTId(uint256 id);
error InvalidRoyalty();
error InvalidPrice();
error InsufficientBalance(address seller, uint256 nftID);

/// @title Zodiak33 Marketplace
/// @author Saad Igueninni
/// @notice Listing/buying of ZodiakTickets :
/// @dev All function calls are currently implemented without side effects

contract ZodiakMarketplace is ERC1155Holder, ReentrancyGuard {
    using Counters for Counters.Counter;

    event ItemListingCreated (
        uint256 indexed listingTokenId,
        address owner,
        address seller,
        uint256 price,
        uint256 amount
    );   
    event  ItemSellPaused( uint256 indexed listingTokenId );
    event  ItemSellCanceled( uint256 indexed listingTokenId );


    //Stats
    Counters.Counter private _nbListedCounter;
    Counters.Counter private _nbSoldCounter;

    address private theMighty; // The creator and administrator of the contract

    IERC1155 private zodiakNFT; // ZodiakNFT contract address
    uint256 private cosmicCouncilFee = 250; //CosmicConcilFee --> To be discussed with the team

    struct ZodiakMarketItem {
        uint256 listingTokenId; // sell order number
        uint256 nftId; // to check with @Scott
        uint256 amount; // amount to sell
        uint256 price; // Price per ticket/price of the group?
        uint256 royalty;
        // uint256 nbSellsCounter;// Counter to track number of sales but how to deal with amount...
        address payable seller;
        address payable owner;
        bool paused;
        bool sold;
    }

    mapping(uint256 => ZodiakMarketItem) private idToMarketItem; //keep track of all listed ZodiakMarketItem indexed by an icremental id ; mapping or array?

    // Only theMighty can call this function
    modifier onlyTheMighty() {
        require(
            msg.sender == theMighty,
            "Only the mighty can call this function"
        );
        _;
    }

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
            revert InvalidNFTId(nftId);
        } //"nftId does not exist"
        if (royalty < 0 || royalty > 300) {
            revert InvalidRoyalty();
        } //To be discussed with the team and then put as an Error
        if (price < 0) {
            revert InvalidPrice();
        } //Should not be negative
        if (amount < 0 || zodiakNFT.balanceOf(msg.sender, nftId) < amount) {
            revert InsufficientBalance(msg.sender, nftId);
        }

        _nbListedCounter.increment();
        uint256 listingTokenId = _nbListedCounter.current();
        // uint256 nbSellsCounter = 0;

        idToMarketItem[listingTokenId] = ZodiakMarketItem(
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
            msg.value == idToMarketItem[listingTokenId].price,
            "Not enough money to buy"
        );

        uint256 price = idToMarketItem[listingTokenId].price;
        uint256 royaltyFee = (price * idToMarketItem[listingTokenId].royalty) /
            10000;
        uint256 zodiacMarketFee = (price * cosmicCouncilFee) / 10000; //TODO --> depends on who receive the royaltyFee and if the logic? first sell no royalty fees, second to who and so on
        // TODO --> if no royalties --> royaltyFee = 0
        uint256 amountToSendToSeller = price - royaltyFee - zodiacMarketFee;

        // Update marketItem array
        idToMarketItem[listingTokenId].sold = true;
        idToMarketItem[listingTokenId].owner = payable(msg.sender);
        _nbSoldCounter.increment();

        //Transfer ERC1155 tickets to buyer
        zodiakNFT.safeTransferFrom(
            idToMarketItem[listingTokenId].owner,
            msg.sender,
            idToMarketItem[listingTokenId].nftId,
            idToMarketItem[listingTokenId].amount,
            ""
        );

        // TODO -->  calculate Royalties
        // check if resale then pay royalties? only to first seller? or 1 time to last seller?
        //Transfer cosmicCouncilFee to where? this contract? another global wallet?
        //Transfer royalties to who?

        // TODO -->  calculate cosmicCouncilFee
        //Transfer cosmicCouncilFee to where? this contract? another global wallet?
        payable(address(this)).transfer(cosmicCouncilFee);

        // TODO -->  send money to seller --> amountToSendToSeller
        payable(idToMarketItem[listingTokenId].seller).transfer(amountToSendToSeller);

        // TODO -->  Emit event 'Buyed'
    }

    function fetchListedItems() public view returns( ZodiakMarketItem[] memory) {

        uint256 itemsCount = _nbListedCounter.current();
        ZodiakMarketItem[] memory listedItems = new ZodiakMarketItem[](itemsCount);
        uint256 currentIndex = 0;

        for(uint i=0;i<itemsCount;i++)
        {
            uint currentId = i + 1;
            ZodiakMarketItem storage currentItem = idToMarketItem[currentId];
            //exclude sold and paused items
            if( !currentItem.paused && !currentItem.sold ){listedItems[currentIndex] = currentItem;}
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return listedItems;

    }

    function cancelSell(uint256 listingTokenId) external {
        
        emit ItemSellCanceled(listingTokenId);
    }

    function pauseSell(uint256 listingTokenId) external {
        idToMarketItem[listingTokenId].paused = true;
        emit ItemSellPaused(listingTokenId);
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
