// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Optimism interface for cross domain messaging
import {ICrossDomainMessenger} from
    "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import {IOpWorldID} from "./interfaces/IOpWorldID.sol";
import {IRootHistory} from "./interfaces/IRootHistory.sol";
import {IWorldIDIdentityManager} from "./interfaces/IWorldIDIdentityManager.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {ICrossDomainOwnable3} from "./interfaces/ICrossDomainOwnable3.sol";

/// @title World ID State Bridge Optimism
/// @author Worldcoin
/// @notice Distributes new World ID Identity Manager roots to an OP Stack network
/// @dev This contract lives on Ethereum mainnet and works for Optimism and any OP Stack based chain
contract OpStateBridge is Ownable2Step {
    ///////////////////////////////////////////////////////////////////
    ///                           STORAGE                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice The address of the OpWorldID contract on any OP Stack chain
    address public immutable opWorldIDAddress;

    /// @notice address for OP Stack chain Ethereum mainnet L1CrossDomainMessenger contract
    address internal immutable crossDomainMessengerAddress;

    /// @notice Ethereum mainnet worldID Address
    address public immutable worldIDAddress;

    /// @notice Amount of gas purchased on the OP Stack chain for _propagateRoottimism
    uint32 internal _gasLimitSendRootOp;

    /// @notice Amount of gas purchased on the OP Stack chain for setRootHistoryExpiryOptimism
    uint32 internal _gasLimitSetRootHistoryExpiryOp;

    /// @notice Amount of gas purchased on the OP Stack chain for transferOwnershipOptimism
    uint32 internal _gasLimitTransferOwnershipOp;

    ///////////////////////////////////////////////////////////////////
    ///                            EVENTS                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Emmitted when the the StateBridge gives ownership of the OPWorldID contract
    /// to the WorldID Identity Manager contract away
    /// @param previousOwner The previous owner of the OPWorldID contract
    /// @param newOwner The new owner of the OPWorldID contract
    /// @param isLocal Whether the ownership transfer is local (Optimism/OP Stack chain EOA/contract)
    /// or an Ethereum EOA or contract
    event OwnershipTransferredOp(
        address indexed previousOwner, address indexed newOwner, bool isLocal
    );

    /// @notice Emmitted when the the StateBridge sends a root to the OPWorldID contract
    /// @param root The root sent to the OPWorldID contract on the OP Stack chain
    event RootPropagated(uint256 root);

    /// @notice Emmitted when the the StateBridge sets the root history expiry for OpWorldID and PolygonWorldID
    /// @param rootHistoryExpiry The new root history expiry
    event SetRootHistoryExpiryOp(uint256 rootHistoryExpiry);

    /// @notice Emmitted when the the StateBridge sets the gas limit for sendRootOp
    /// @param _opGasLimit The new opGasLimit for sendRootOp
    event SetGasLimitSendRootOp(uint32 _opGasLimit);

    /// @notice Emmitted when the the StateBridge sets the gas limit for setRootHistoryExpiryOpt
    /// @param _opGasLimit The new opGasLimit for setRootHistoryExpiryOptimism
    event SetGasLimitSetRootHistoryExpiryOp(uint32 _opGasLimit);

    /// @notice Emmitted when the the StateBridge sets the gas limit for transferOwnershipOp
    /// @param _opGasLimit The new opGasLimit for transferOwnershipOptimism
    event SetGasLimitTransferOwnershipOp(uint32 _opGasLimit);

    ///////////////////////////////////////////////////////////////////
    ///                            ERRORS                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Thrown when an attempt is made to renounce ownership.
    error CannotRenounceOwnership();

    ///////////////////////////////////////////////////////////////////
    ///                         CONSTRUCTOR                         ///
    ///////////////////////////////////////////////////////////////////

    /// @notice constructor
    /// @param _worldIDIdentityManager Deployment address of the WorldID Identity Manager contract
    /// @param _opWorldIDAddress Address of the Optimism contract that will receive the new root and timestamp
    /// @param _crossDomainMessenger L1CrossDomainMessenger contract used to communicate with the desired OP
    /// Stack network
    constructor(
        address _worldIDIdentityManager,
        address _opWorldIDAddress,
        address _crossDomainMessenger
    ) {
        opWorldIDAddress = _opWorldIDAddress;
        worldIDAddress = _worldIDIdentityManager;
        crossDomainMessengerAddress = _crossDomainMessenger;
        _gasLimitSendRootOp = 100000;
        _gasLimitSetRootHistoryExpiryOp = 100000;
        _gasLimitTransferOwnershipOp = 100000;
    }

    ///////////////////////////////////////////////////////////////////
    ///                          PUBLIC API                         ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Sends the latest WorldID Identity Manager root to the IOpStack.
    /// @dev Calls this method on the L1 Proxy contract to relay roots and timestamps to WorldID supported chains.
    function propagateRoot() external {
        uint256 latestRoot = IWorldIDIdentityManager(worldIDAddress).latestRoot();

        // The `encodeCall` function is strongly typed, so this checks that we are passing the
        // correct data to the optimism bridge.
        bytes memory message = abi.encodeCall(IOpWorldID.receiveRoot, (latestRoot));

        ICrossDomainMessenger(crossDomainMessengerAddress).sendMessage(
            // Contract address on the OP Stack Chain
            opWorldIDAddress,
            message,
            _gasLimitSendRootOp
        );

        emit RootPropagated(latestRoot);
    }

    /// @notice Adds functionality to the StateBridge to transfer ownership
    /// of OpWorldID to another contract on L1 or to a local OP Stack chain EOA
    /// @param _owner new owner (EOA or contract)
    /// @param _isLocal true if new owner is on Optimism, false if it is a cross-domain owner
    function transferOwnershipOp(address _owner, bool _isLocal) external onlyOwner {
        bytes memory message;

        // The `encodeCall` function is strongly typed, so this checks that we are passing the
        // correct data to the OP Stack chain bridge.
        message = abi.encodeCall(ICrossDomainOwnable3.transferOwnership, (_owner, _isLocal));

        ICrossDomainMessenger(crossDomainMessengerAddress).sendMessage(
            // Contract address on the OP Stack Chain
            opWorldIDAddress,
            message,
            _gasLimitTransferOwnershipOp
        );

        emit OwnershipTransferredOp(owner(), _owner, _isLocal);
    }

    /// @notice Adds functionality to the StateBridge to set the root history expiry on OpWorldID
    /// @param _rootHistoryExpiry new root history expiry
    function setRootHistoryExpiryOp(uint256 _rootHistoryExpiry) external onlyOwner {
        bytes memory message;

        // The `encodeCall` function is strongly typed, so this checks that we are passing the
        // correct data to the optimism bridge.
        message = abi.encodeCall(IRootHistory.setRootHistoryExpiry, (_rootHistoryExpiry));

        ICrossDomainMessenger(crossDomainMessengerAddress).sendMessage(
            // Contract address on the OP Stack Chain
            opWorldIDAddress,
            message,
            _gasLimitSetRootHistoryExpiryOp
        );

        emit SetRootHistoryExpiryOp(_rootHistoryExpiry);
    }

    ///////////////////////////////////////////////////////////////////
    ///                         OP GAS LIMIT                        ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Sets the gas limit for the sendRootOp method
    /// @param _opGasLimit The new gas limit for the sendRootOp method
    function setGasLimitSendRootOp(uint32 _opGasLimit) external onlyOwner {
        _gasLimitSetRootHistoryExpiryOp = _opGasLimit;

        emit SetGasLimitSendRootOp(_opGasLimit);
    }

    /// @notice Sets the gas limit for the setRootHistoryExpiryOp method
    /// @param _opGasLimit The new gas limit for the setRootHistoryExpiryOp method
    function setGasLimitSetRootHistoryExpiryOp(uint32 _opGasLimit) external onlyOwner {
        _gasLimitSetRootHistoryExpiryOp = _opGasLimit;

        emit SetGasLimitSetRootHistoryExpiryOp(_opGasLimit);
    }

    /// @notice Sets the gas limit for the transferOwnershipOp method
    /// @param _opGasLimit The new gas limit for the transferOwnershipOp method
    function setGasLimitTransferOwnershipOp(uint32 _opGasLimit) external onlyOwner {
        _gasLimitTransferOwnershipOp = _opGasLimit;

        emit SetGasLimitTransferOwnershipOp(_opGasLimit);
    }

    ///////////////////////////////////////////////////////////////////
    ///                          OWNERSHIP                          ///
    ///////////////////////////////////////////////////////////////////
    /// @notice Ensures that ownership of WorldID implementations cannot be renounced.
    /// @dev This function is intentionally not `virtual` as we do not want it to be possible to
    ///      renounce ownership for any WorldID implementation.
    /// @dev This function is marked as `onlyOwner` to maintain the access restriction from the base
    ///      contract.
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
    }
}
