// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IERC5050RegistryClient } from "./interfaces/IERC5050RegistryClient.sol";
import { IERC5050Receiver, IERC5050Sender } from "./interfaces/IERC5050.sol";

contract RegistryClientProxy {
    IERC5050RegistryClient proxyRegistry;
    address internal selfIsProxyForSender;
    address internal selfIsProxyForReceiver;
    mapping(address => mapping(bytes4 =>address)) _lookup;

    function _setProxyRegistry(address _proxyRegistry) internal {
        proxyRegistry = IERC5050RegistryClient(_proxyRegistry);
    }

    function register(address _contract, bytes4 interfaceId, address _proxy) external {
        _lookup[_contract][interfaceId] = _proxy;
    }

    function deregister(address _contract, bytes4 interfaceId) external {
        delete _lookup[_contract][interfaceId];
    }

    function getInterfaceImplementer(address _addr, bytes4 _interfaceId) external view returns (address) {
        return _lookup[_addr][_interfaceId];
    }
    
    // Not used or implemented for this example.
    // function getManager(address _contract) external view returns (address) {
    //     return _contract;
    // }

    function getSenderProxy(address _addr) internal view returns (address) {
        if(_addr == address(0)){
            return _addr;
        }
        if(selfIsProxyForSender == _addr) {
            return address(this);
        }
        if(address(proxyRegistry) == address(0)){
            return _addr;
        }
        return proxyRegistry.getInterfaceImplementer(_addr, type(IERC5050Sender).interfaceId);
    }

    function getReceiverProxy(address _addr) internal view returns (address) {
        if(_addr == address(0)){
            return _addr;
        }
        if(selfIsProxyForReceiver == _addr) {
            return address(this);
        }
        if(address(proxyRegistry) == address(0)){
            return _addr;
        }
        return proxyRegistry.getInterfaceImplementer(_addr, type(IERC5050Receiver).interfaceId);
    }
}
