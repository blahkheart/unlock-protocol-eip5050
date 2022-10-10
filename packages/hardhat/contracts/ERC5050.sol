// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

/******************************************************************************\
* Author: hypervisor <chitch@alxi.nl> (https://twitter.com/0xalxi)
* EIP-5050 Token Interaction Standard: https://eips.ethereum.org/EIPS/eip-5050
*
* Implementation of an interactive token protocol.
/******************************************************************************/

// import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC5050.sol";
import {ActionsSet} from "./libraries/ActionsSet.sol";
import "./ERC5050RegistryClientProxy.sol";

// contract ERC5050 is ERC165, RegistryClientProxy, Ownable {
contract ERC5050 is RegistryClientProxy, Ownable {
    using Address for address;
    using ActionsSet for ActionsSet.Set;
    
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private reentrancyLock;
    
    ActionsSet.Set private _receivableActions;
    ActionsSet.Set private _sendableActions;

    uint256 private _nonce;
    bytes32 private _hash;
    
    event ActionReceived(
         bytes4 indexed name,
        address _from,
        address indexed _fromContract,
        uint256 _tokenId,
        address indexed _to,
        uint256 _toTokenId,
        address _state,
        bytes _data
    );

    /// @dev This emits when the approved address for an account-action pair
    ///  is changed or reaffirmed. The zero address indicates there is no
    ///  approved address.
    event ApprovalForAction(
        address indexed _account,
        bytes4 indexed _action,
        address indexed _approved
    );

    /// @dev This emits when an operator is enabled or disabled for an account.
    ///  The operator can conduct all actions on behalf of the account.
    event ApprovalForAllActions(
        address indexed _account,
        address indexed _operator,
        bool _approved
    );
    /// @dev This emits when an action is sent (`sendAction()`)
    event SendAction(
        bytes4 indexed name,
        address _from,
        address indexed _fromContract,
        uint256 _tokenId,
        address indexed _to,
        uint256 _toTokenId,
        address _state,
        bytes _data
    );
    mapping(address => mapping(bytes4 => address)) actionApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;


    function setProxyRegistry(address registry) external virtual onlyOwner {
        _setProxyRegistry(registry);
    }
    function _registerAction(string memory action) internal {
        _registerSendable(action);
        _registerReceivable(action);
    }
    
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    // function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
    //     return
    //         interfaceId == type(IERC5050Sender).interfaceId ||
    //         interfaceId == type(IERC5050Receiver).interfaceId ||
    //         super.supportsInterface(interfaceId);
    // }
   
    modifier onlySendableAction(Action memory action) {
        require(
            reentrancyLock == _NOT_ENTERED,
            "ERC5050: reentrant call"
        );
        require(
            _sendableActions.contains(action.selector),
            "ERC5050: invalid action"
        );
        require(
            _isApprovedOrSelf(action.user, action.selector),
            "ERC5050: unapproved sender"
        );
        require(
            action.from._address == address(this) ||
                getSenderProxy(action.from._address) == address(this),
            "ERC5050: invalid from address"
        );
        reentrancyLock = _ENTERED;
        _;
        reentrancyLock = _NOT_ENTERED;
    }

    modifier onlyReceivableAction(Action calldata action, uint256 nonce) {
        require(reentrancyLock == _NOT_ENTERED, "ERC5050: reentrant call");
        require(
            action.to._address == address(this) ||
                getReceiverProxy(action.to._address) == address(this),
            "ERC5050: invalid receiver"
        );
        require(
            _receivableActions.contains(action.selector),
            "ERC5050: invalid action"
        );
        require(
            action.from._address == address(0) ||
                action.from._address == msg.sender ||
                getSenderProxy(action.from._address) == msg.sender,
            "ERC5050: invalid sender"
        );
        require(
            (action.from._address != address(0) && action.user == tx.origin) ||
                action.user == msg.sender,
            "ERC5050: invalid sender"
        );
        reentrancyLock = _ENTERED;
        _;
        reentrancyLock = _NOT_ENTERED;
    }

    function receivableActions() external view returns (string[] memory) {
        return _receivableActions.names();
    }

    function onActionReceived(Action calldata action, uint256 nonce)
        external
        payable
        virtual
        onlyReceivableAction(action, nonce)
    {
        _onActionReceived(action, nonce);
    }

    function _onActionReceived(Action calldata action, uint256 nonce)
        internal
        virtual
    {
        if (action.state != address(0)) {
            address next = getReceiverProxy(action.state);
            require(next.isContract(), "ERC5050: invalid state");
            try
                IERC5050Receiver(next).onActionReceived{
                    value: msg.value
                }(action, nonce)
            {} catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC5050: call to non ERC5050Receiver");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
        emit ActionReceived(
            action.selector,
            action.user,
            action.from._address,
            action.from._tokenId,
            action.to._address,
            action.to._tokenId,
            action.state,
            action.data
        );
    }

    function sendAction(Action memory action)
        external
        payable
        virtual
    {
        _sendAction(action);
    }

    function isValid(bytes32 actionHash, uint256 nonce)
        external
        view
        returns (bool)
    {
        return actionHash == _hash && nonce == _nonce;
    }

    function sendableActions() external view returns (string[] memory) {
        return _sendableActions.names();
    }

    function approveForAction(
        address _account,
        bytes4 _action,
        address _approved
    ) public virtual returns (bool) {
        require(_approved != _account, "ERC5050: approve to caller");

        require(
            msg.sender == _account ||
                isApprovedForAllActions(_account, msg.sender),
            "ERC5050: approve caller is not account nor approved for all"
        );

        actionApprovals[_account][_action] = _approved;
        emit ApprovalForAction(_account, _action, _approved);

        return true;
    }

    function setApprovalForAllActions(address _operator, bool _approved)
        public
        virtual
    {
        require(msg.sender != _operator, "ERC5050: approve to caller");

        operatorApprovals[msg.sender][_operator] = _approved;

        emit ApprovalForAllActions(msg.sender, _operator, _approved);
    }

    function getApprovedForAction(address _account, bytes4 _action)
        public
        view
        returns (address)
    {
        return actionApprovals[_account][_action];
    }

    function isApprovedForAllActions(address _account, address _operator)
        public
        view
        returns (bool)
    {
        return operatorApprovals[_account][_operator];
    }

    function _sendAction(Action memory action) internal {
        bool toIsContract = action.to._address.isContract();
        bool stateIsContract = action.state.isContract();
        address next;
        if (toIsContract) {
            next = action.to._address;
        } else if (stateIsContract) {
            next = action.state;
        }
        uint256 nonce;
        if (toIsContract && stateIsContract) {
            _validate(action);
            nonce = _nonce;
        }
        if(next != address(0)){
            next = getReceiverProxy(next);
        }
        if (next.isContract()) {
            try
                IERC5050Receiver(next).onActionReceived{value: msg.value}(
                    action,
                    nonce
                )
            {} catch Error(string memory err) {
                revert(err);
            } catch (bytes memory returnData) {
                if (returnData.length > 0) {
                    revert(string(returnData));
                }
            }
        }
        emit SendAction(
            action.selector,
            action.user,
            action.from._address,
            action.from._tokenId,
            action.to._address,
            action.to._tokenId,
            action.state,
            action.data
        );
    }

    function _validate(Action memory action) internal {
        ++_nonce;
        _hash = bytes32(
            keccak256(
                abi.encodePacked(
                    action.selector,
                    action.user,
                    action.from._address,
                    action.from._tokenId,
                    action.to._address,
                    action.to._tokenId,
                    action.state,
                    action.data,
                    _nonce
                )
            )
        );
    }

    function _isApprovedOrSelf(address account, bytes4 action)
        internal
        view
        returns (bool)
    {
        return (msg.sender == account ||
            isApprovedForAllActions(account, msg.sender) ||
            getApprovedForAction(account, action) == msg.sender);
    }

    function _registerSendable(string memory action) internal {
        _sendableActions.add(action);
    }

    function _registerReceivable(string memory action) internal {
        _receivableActions.add(action);
    }
}
