// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error nftsCountMismatchAmounts();
error invalidAmountToSell();
error InvalidNFTId(uint256 id);
error InvalidPrice();
error InsufficientBalance(address seller, uint256 nftID);
error marketPlaceNotApprovedForAll();
error notEnoughMoneySenrToBuyItem();

/// @title Zodiak33 Marketplace
/// @author Saad Igueninni
/// @notice Listing/buying of ZodiakTickets :
/// @dev All function calls are currently implemented without side effects
contract ZodiakMarketplace is  ReentrancyGuard {
    using Counters for Counters.Counter;

    event ItemListingCreated(ZodiakMarketItem zodiakMarketItem);
    event ItemSellPaused(uint256 indexed listingTokenId);
    event ItemSellCanceled(uint256 indexed listingTokenId);
    event ItemSellTerminated(uint256 indexed listingTokenId);

    //Stats
    Counters.Counter private _nbListedCounter;
    Counters.Counter private _nbSoldCounter;

    address private theMighty; // The creator and administrator of the contract

    IERC1155 public immutable zodiakNFT; // ZodiakNFT contract address

    struct ZodiakMarketItem {
        uint256[] nftIds;
        uint256[] amounts;
        uint256 price; // Price of the lot
        address payable seller;
        address actualOwner; // seller is owner until buy, then buyer is owner
        bool paused;
        bool sold;
    }

    mapping(uint256 => ZodiakMarketItem) public idToMarketItem; //keep track of all listed ZodiakMarketItem indexed by an icremental id

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
        uint256[] memory nftIds,
        uint256[] memory amounts,
        uint256 price
    ) external {
        if (nftIds.length != amounts.length) {
            revert nftsCountMismatchAmounts();
        }

        if (amounts.length == 0) {
            revert invalidAmountToSell();
        }

        uint256 nftId;
        uint256 amount;
        for (uint256 i = 0; i < nftIds.length; i++) {
            nftId = nftIds[i];
            amount = amounts[i];
            if (nftId < 0 || nftId > 13) {
                //yes 13 is included, starting 14 is an error
                revert InvalidNFTId(nftId);
            } //"nftId does not exist"

            if (amount < 0 || zodiakNFT.balanceOf(msg.sender, nftId) < amount) {
                revert InsufficientBalance(msg.sender, nftId);
            }
        }

        if (price < 0) {
            revert InvalidPrice();
        } //Should not be negative

        _nbListedCounter.increment(); // as of OZ, we cannot overflow uint so Unchecked incremental
        uint256 listingTokenId = _nbListedCounter.current();

        idToMarketItem[listingTokenId] = ZodiakMarketItem(
            nftIds,
            amounts,
            price,
            payable(msg.sender),
            msg.sender,
            false,
            false
        );

        emit ItemListingCreated(idToMarketItem[listingTokenId]);
    }

    /// @notice  Buy the NFT from marketplace.
    /// @dev User will able to buy NFT and transfer to respectively owner or user
    function buyNFT(uint256 listingTokenId) external payable nonReentrant {
        if (msg.value != idToMarketItem[listingTokenId].price) {
            revert notEnoughMoneySenrToBuyItem();
        }

        if (!zodiakNFT.isApprovedForAll(idToMarketItem[listingTokenId].actualOwner, address(this))) {
            revert marketPlaceNotApprovedForAll();
        } //MarketPlace must be approved

        // Update marketItem array
        idToMarketItem[listingTokenId].sold = true;
        idToMarketItem[listingTokenId].actualOwner = msg.sender;
        _nbSoldCounter.increment();

        //Transfer ERC1155 tickets to buyer
        zodiakNFT.safeBatchTransferFrom( //(from, to, ids, amounts, data)(
            idToMarketItem[listingTokenId].actualOwner,
            msg.sender,
            idToMarketItem[listingTokenId].nftIds,
            idToMarketItem[listingTokenId].amounts,
            ""
        );

        //Transfer money to seller
        payable(idToMarketItem[listingTokenId].seller).transfer(
            idToMarketItem[listingTokenId].price
        );

        emit ItemSellTerminated(listingTokenId);
    }

    function fetchMyItems() external view returns (ZodiakMarketItem[] memory) {
        //TODO check msg.sender is actual owner and not paused and not sold
    }

    function fetchListedItems()
        public
        view
        returns (ZodiakMarketItem[] memory)
    {
        uint256 itemsCount = _nbListedCounter.current();
        ZodiakMarketItem[] memory listedItems = new ZodiakMarketItem[](
            itemsCount
        );
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < itemsCount; i++) {
            uint256 currentId = i + 1;
            ZodiakMarketItem storage currentItem = idToMarketItem[currentId];
            //exclude sold and paused items
            if (!currentItem.paused && !currentItem.sold) {
                listedItems[currentIndex] = currentItem;
            }
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


    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }


}
