// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

error InvalidId(uint256 id);


/// @title Zodiak33 Marketplace
/// @author Saad Igueninni
/// @notice Listing/buying of ZodiakTickets U ( can be wining tickets 
/// @dev All function calls are currently implemented without side effects

contract ZodiakMarketplace is ERC1155Holder {
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


    constructor(address _zodiakNFT, address _theMighty) {
        zodiakNFT = IERC1155(_zodiakNFT);
        theMighty = _theMighty;
    }

    struct ZodiakMarketItem {
        uint256 listingTokenId;
        uint256 nftId;  // to check with @Scott
        uint256 amount; //not needed
        uint256 price;
        uint256 royalty;
        address payable seller;
        address payable owner;
        bool sold;
        bool winingTicket;
    }

    mapping(uint256 => ZodiakMarketItem) private marketItem; //keep track of all listed ZodiakMarketItem indexed by an icremental id

    /// @notice It will list the NFT to marketplace.
    /// @dev It will list NFT minted from MFTMint contract.
    function listNft(
        uint256 nftId,
        uint256 amount,
        uint256 price,
        uint256 royalty,
        bool winingTicket
    ) external {

         if (nftId <= 0) {
            revert InvalidId(nftId); //"Token does not exist"
        }

        require(royalty >= 0, "royalty should be between 0 to xxx"); //To be discussed with the team and then put as an Error
        require(royalty < 299, "royalty should be less than xxx ");   //To be discussed with the team and then put as an Error

        _nbListedCounter.increment();
        uint256 listingTokenId = _nbListedCounter.current();

        marketItem[listingTokenId] = ZodiakMarketItem(
            listingTokenId,
            nftId,
            amount,
            price,
            royalty,
            payable(msg.sender),
            payable(msg.sender),
            false,
            winingTicket

        );

        IERC1155(zodiakNFT).safeTransferFrom(
            msg.sender,
            address(this),
            nftId,
            amount, //  is the amount needed?
            ""
        );
    }

    /// @notice  Buy the NFT from marketplace.
    /// @dev User will able to buy NFT and transfer to respectively owner or user and platform fees, 
    /// royalty fees also deducted 

    function buyNFT(uint256 tokenId, uint256 amount) external payable {
        uint256 price = marketItem[tokenId].price;
        uint256 royaltyFee = (price * marketItem[tokenId].royalty) / 10000;
        uint256 zodiacMarketFee = (price * cosmicCouncilFee) / 10000;

        zodiakNFT.safeTransferFrom(msg.sender, address(this), 0, price, "");
        zodiakNFT.safeTransferFrom(
            msg.sender,
            marketItem[tokenId].owner,
            0,
            royaltyFee,
            ""
        );
        zodiakNFT.safeTransferFrom(
            msg.sender,
            address(this),
            0,
            zodiacMarketFee,
            ""
        );

        marketItem[tokenId].owner = payable(msg.sender);
        _nbSoldCounter.increment();

        onERC1155Received(address(this), msg.sender, tokenId, amount, "");

        zodiakNFT.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
    }

    /// @notice  CosmicCouncilFee getter 
    function setCosmicCouncilFee(uint256 _cosmicCouncilFee) public {
        cosmicCouncilFee = _cosmicCouncilFee;
    }


    /// @notice  CosmicCouncilFee setter
    function getCosmicCouncilFee() onlyTheMighty public view returns  (uint256) {
        return cosmicCouncilFee;
    }

}
