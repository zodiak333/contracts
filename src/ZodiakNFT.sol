//SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {
    ERC1155URIStorage, ERC1155, Strings
} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract ZodiakNFT is ERC1155URIStorage {
    using Strings for uint256;

    // address immutable CosmicLottery;
    address private theMighty; // The creator and administrator of the contract
    address private cosmicLottery; // The lottery contract
    uint256 private maxCollections = 18;
    uint256 private maxZodiaks = 12;

    struct Zodiak {
        uint16 strength;
        uint16 agility;
        uint16 intelligence;
        uint16 vitality;
        uint16 luck;
    }

    mapping(uint256 => Zodiak) public zodiakBonuses;

    // Only the CosmicLottery and theMighty can call this function
    modifier cosmicAuthority() {
        require(msg.sender == cosmicLottery || msg.sender == theMighty, "Only Cosmic powers can call this function");
        _;
    }

    constructor(string memory _uri, address _theMighty) ERC1155(_uri) {
        theMighty = _theMighty;
        cosmicLottery = msg.sender;
    }

    //CHECK: bookkeeping ?
    //astralBirth or summonLuck
    function createTicket(uint256 _amount, address _summoner) public cosmicAuthority {
        require(balanceOf(_summoner, 0) + _amount <= 10, "You can only mint 10 tokens");
        _mint(_summoner, 0, _amount, "");
    }

    /**
     * @dev Mutate a NFT from an collection id to an other
     * @param _idFrom the id of the NFT to mutate
     * @param _idTo the id of the NFT to mutate to
     * @param _owner the owner of the NFT
     */
    function cosmicMutation(uint256 _idFrom, uint256 _idTo, address _owner) public cosmicAuthority {
        require(balanceOf(_owner, _idFrom) >= 1, "Insufficient balance");
        require(_idFrom <= maxCollections && _idTo <= maxCollections, "Invalid id");
        _burn(_owner, _idFrom, 1);
        _mint(_owner, _idTo, 1, "");
    }

    /**
     * @dev burn a NFT
     * @param tokenId the collection id of the NFT to burn
     * @param _from the owner of the NFT
     * @param _amount the amount of NFT to burn
     */
    function voidRelease(uint256 tokenId, address _from, uint256 _amount) public {
        _burn(_from, tokenId, _amount);
    }

    /**
     * @dev Reshape the bonuses of a Zodiak
     * @param _id the id of the NFT to reshape
     * @param _strength the strength of the NFT
     * @param _agility the agility of the NFT
     * @param _intelligence the intelligence of the NFT
     * @param _vitality the vitality of the NFT
     * @param _luck the luck of the NFT
     */
    function cosmicReshape(
        uint256 _id,
        uint16 _strength,
        uint16 _agility,
        uint16 _intelligence,
        uint16 _vitality,
        uint16 _luck
    ) public cosmicAuthority {
        zodiakBonuses[_id] = Zodiak(_strength, _agility, _intelligence, _vitality, _luck);
    }

    /**
     * @dev Set the URI of the all the collections, including Zodiaks, wheel spinning tickets, winning tickets and prize tickets
     */
    function initURI(string[] memory _uris) public cosmicAuthority {
        for (uint256 i = 0; i < _uris.length; i++) {
            _setURI(i, _uris[i]);
        }
    }

    /**
     * @dev Set the max number of collections
     * @param _maxCollections the max number of collections
     */
    function setMaxCollections(uint256 _maxCollections) public cosmicAuthority {
        maxCollections = _maxCollections;
    }
}
