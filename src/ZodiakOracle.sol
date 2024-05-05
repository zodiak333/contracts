//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

//import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/dev/interfaces/IVRFCoordinatorV2Plus.sol";


import {IVRFCoordinatorV2Plus}  from "@chainlink/contracts/src/v0.8/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus}  from "@chainlink/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient}        from "@chainlink/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";
import {FunctionsClient}        from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner}         from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest}       from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

/// @title Zodiak33 Oracle
/// @notice This Oracle compiles all necessary oracle functionnalities needed for Zodiak33
/// @dev This Oracle uses Chainlink  VRF2.5 and functions
contract ZodiakOracle is
    FunctionsClient,
    ConfirmedOwner,
    VRFConsumerBaseV2Plus
{
    using FunctionsRequest for FunctionsRequest.Request;

    event RandomRequestSent(uint256 requestId, uint32 numWords);
    event RandomRequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RandomRequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RandomRequestStatus) public s_requests; /* requestId --> requestStatus */

    // Contract address that we will use to request randomness
    IVRFCoordinatorV2Plus COORDINATOR;

    // Your subscription ID.
    uint256 s_randomSubscriptionId;

    // past requests Id. Needed?
    uint256[] public randomRequestIds;
    uint256 public randomLastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2-5/supported-networks
    bytes32 keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // Bydefault, We retrieve 1 random value in one request.
    // Can be changed
    uint32 numWords = 1;

    // Router address - Hardcoded for Sepolia
    // State variables to store the last request ID, response, and error
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string character,
        bytes response,
        bytes err
    );

    // Router address - Hardcoded for Sepolia
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // JavaScript source code
    // Fetch character name from the Star Wars API.
    // Documentation: https://swapi.info/people
    string source =
        "const characterId = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: `https://swapi.info/api/people/${characterId}/`"
        "});"
        "if (apiResponse.error) {"
        "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "return Functions.encodeString(data.name);";

    //Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Sepolia
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // State variable to store the returned character information
    string public character;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
     */
    constructor(uint256 subscriptionId)
        VRFConsumerBaseV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B)
        FunctionsClient(router)
    {
        COORDINATOR = IVRFCoordinatorV2Plus(
            0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
        );
        s_randomSubscriptionId = subscriptionId;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        // To enable payment in native tokens, set nativePayment to true.
        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_randomSubscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s_requests[requestId] = RandomRequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        randomRequestIds.push(requestId);
        randomLastRequestId = requestId;
        emit RandomRequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RandomRequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].exists, "request not found");
        RandomRequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function setRandomInRange(
        uint256 randomWord,
        uint16 rangeLow,
        uint16 rangeHigh
    ) public pure returns (uint256) {
        // Assuming only one random word was requested.
        return (randomWord % rangeHigh) + 1 + rangeLow;
    }

    /**
     * @dev Sets `numWords` num random values to be retrieved
     */
    function _setNumWords(uint32 _numWords) internal {
        numWords = _numWords;
    }

    /**
     * @notice Sends an HTTP request for character information
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(uint64 subscriptionId, string[] calldata args)
        external
        onlyOwner
        returns (bytes32 requestId)
    {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        character = string(response);
        s_lastError = err;

        // Emit an event to log the response
        emit Response(requestId, character, s_lastResponse, s_lastError);
    }
}
