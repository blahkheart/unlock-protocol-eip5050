// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
* Author: alxi <chitch@alxi.nl> (https://twitter.com/0xalxi)
* EIP-5050 Token Interaction Standard: [tbd]
*
* Implementation of an interactive token protocol.

                                                                              /&&&%%%&&&&&&&.                           
                                                                            /%&@&%&ҹ%%%%&&&&&@.                         
                                                                           /%&&%&%%ҹҹ%ҹ%%&&%&&@                         
                                                                           ҹ(%%ҹҹҹҹҹҹҹ%ҹҹҹ%&&&&                         
                                                                           (ҹҹҹ((ҹҹҹ(ҹҹ(ҹ%%%&&%                         
                                                                           (((ҹ✶((//(((ҹҹҹ%%&&                          
                                                                           .((((✶///////(((ҹҹ%                          
                                                                            ҹ((ҹҹ/✶///✶✶//(ҹҹҹ                          
                                                                            ҹҹҹ((/✶✶/✶✶✶✶// .,.                         
                                                               ,✶✶✶✶✶/,✶   (@@&ҹ(/✶.         (&                         
                                                              ✶✶✶✶✶✶✶(,✶,%%&%&         &%%%%&&&&                        
                                                            ,,✶✶✶,,,✶/,/&%ҹҹ%     ,%%%&&%&&&&&&&&/                      
                                                             ✶✶✶✶✶✶,✶✶/ҹҹҹ&%, ✶&&&%%%&&&&&&&&&&&&&✶                     
                                                      ✶(ҹҹ%(%✶,,,,,✶✶/ҹҹҹ%@%%%&&&&&%%%&&&&&&&&&&&&                      
                                                (ҹҹ%%&%%%%&%%%&&%%&(✶@%/&%&@&%&&&&&&&%%&&&&&&&&&&&                      
                                           (ҹ%%%%%%%%%&%%%&%%&&%%&&&&@&@@&%%@&&&&&&&&&%&&%%&&&&&&&                      
                                     .ҹҹ%%%%%%%%%%%%%%%%@&&%%%%%%%&&&@%%&&&@%&&&&&%%%&%%&%%&&@&@@@                      
                                 %ҹ%%%%%%%%%%%%%&&&&&&&&&&&%%&&&%%%&&&&&&%%&&&&&&%&%%%%&&&&&&&&@&&                      
                            ✶  %%%%%%%%%%%&&&&&&&&%%,    ✶%%%&&%%&%&&&%%%&&&&&%%%%&%&&&&&&&&&&&@@@                      
         ✶✶/✶✶✶✶✶✶✶✶✶✶✶✶✶✶/✶/✶, ✶%&&&&&&&&&&/             %&&%%%&&&&%%&&&%%%%%%&%&&&&&&&&&&&&&&@@✶                      
         ✶✶✶✶,✶✶✶✶✶✶✶,✶✶✶✶//(((,✶&&&&&                    &&%%%%%ҹ%%&&&&%%&%%%%%&&&&&&&&&&&&@@@@&                       
           ..       ✶✶/✶✶✶/((    &&                       %&&%&%&%%%%%%%%%%%&&&&&&&&&&&&&@@&@@@@ҹ,                      
                      .                                   (&&&%%%%%%%%%%&&&&&&&&&&&&&&@&&&&&@@@&&%%%%%%/                
                                                           &&&%%&&&%&%&&&&&&&&&&@@&&&&&@&&&&&&&&%%%%ҹҹ%ҹҹ%ҹҹҹҹ          
                                                          %&&&&&&&&&&&&&&&@@@&&&&&&&&&&&&&&&&&&&&&&%%%%%%%%%%%%%ҹ       
                                                          %@@@&&@&@&@@@@&&&&&&&&&&&&&&&&&&&&&&&&&&&%%%&%%%%&&&&&&&%     
                                                         &&%&@@@&&&&@&%&&&&&&&&%&&&&&&&&&&%&&&&&&&&%%ҹҹ%&&&&&&&&&&&%    
                                                        %&&&&%&&&&&&&&&&&&%%%&%&%&%&&&&&&&&&&@&&&@&%ҹ%&&&&&&&&&&&&&&    
                                                       ✶%%&&&&&&&&&@@&&&&&&%&&&&&&&&%&%&&&&&&&&&&ҹ%&&&&&&&&&&&&&&&&&&   
                                                       &%%&&%&&%%&%%%&%%&%%&&&&&&&&&%%&%&&@&&&&&&&&&&%%&&&&%%&&&&&&&&   
                                                      /&&&&%%%%%%%%%%%%&&%%%%%%%&&&%&&&&&&&&&&&&&&@&&&&%%&&&&ҹ,.        
                                                      &&&&&%%%%%%%%&&&%%%%%&%%%%&&&&&&&%&&&&&&&&&&&&&@&%                
                                                      &%%%%%%%%%%%%%%&&&&&&&&&&&&&&&&&&&&&&&&&@@@@@&&@@&&               
                                                      %%%%%%%%%&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&@&@@&&&&@&&%             
                                                      ҹ%%%%%%&&&&&&&&&&&&&&&&&&@@&&&&&&&&&&&&&@@@&&&&&@&&&&&            
                                                       %%%&%&&&&&&&&@&@@@&@@@&@@&&&&&&&&&&&&&@&&&&&&&@&&&&&,            
                                                       &%&&&&&&&&&&&@@&@@&&@&@@&&&&&&&&&&&&&&&@&&&&&&&&&                

*/

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Action, Object} from "./interfaces/IERC5050.sol";
import "./interfaces/IActionsNFTState.sol";
import "./ERC5050.sol";


contract SlapState is ERC5050, IActionsNFTState {
    using Address for address;

    mapping(address => mapping(uint256 => TokenStats)) stats;

    bytes4 constant SLAP_SELECTOR = bytes4(keccak256("slap"));

    constructor() {
        _registerReceivable("slap");
    }

    function get(address _contract, uint256 tokenId)
        external
        view
        returns (TokenStats memory)
    {
        return stats[_contract][tokenId];
    }

    function registerToken(address _contract, uint256 tokenId) external {
        require(
            stats[_contract][tokenId].strength == 0,
            "State: already registered"
        );
        stats[_contract][tokenId] = TokenStats(
            (_random(_contract, tokenId) % 20) + 4,
            TokenSlapState.DEFAULT
        );
    }

    function getStrength(address _contract, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return stats[_contract][tokenId].strength;
    }

    function getState(address _contract, uint256 tokenId)
        external
        view
        returns (TokenSlapState)
    {
        return stats[_contract][tokenId].state;
    }

    function onActionReceived(Action calldata action, uint256 _nonce)
        external
        payable
        override
        onlyReceivableAction(action, _nonce)
    {
        require(
            action.from._address.isContract() &&
                action.to._address.isContract(),
            "State: invalid to and from"
        );

        TokenStats memory fromStats = _get(action.from);
        TokenStats memory toStats = _get(action.to);
        require(
            fromStats.strength > 0 && toStats.strength > 0,
            "0 strength token"
        );

        uint256 val = (_random(action.from._address, action.from._tokenId) %
            (fromStats.strength + toStats.strength)) + 1;

        // Relative strength determines likelihood of a win.
        if (val == fromStats.strength) {
            // tie
            stats[action.from._address][action.from._tokenId]
                .state = TokenSlapState.DEFAULT;
            stats[action.to._address][action.to._tokenId].state = TokenSlapState
                .DEFAULT;
        } else if (val < fromStats.strength) {
            // sender wins!
            uint256 delta = fromStats.strength - val;
            fromStats.strength += delta;
            fromStats.state = TokenSlapState.WINNER;
            _set(action.from, fromStats);
            if (delta >= toStats.strength) {
                toStats.strength = 0;
                toStats.state = TokenSlapState.DEAD;
            } else {
                toStats.strength -= delta;
                toStats.state = TokenSlapState.SLAPPED;
            }
            _set(action.to, toStats);
        } else {
            // receiver wins!
            uint256 delta = val - fromStats.strength;
            toStats.strength += delta;
            toStats.state = TokenSlapState.WINNER;
            _set(action.to, toStats);

            if (delta >= toStats.strength) {
                fromStats.strength = 0;
                fromStats.state = TokenSlapState.DEAD;
            } else {
                fromStats.strength -= delta;
                fromStats.state = TokenSlapState.SLAPPED;
            }
            _set(action.from, fromStats);
        }
    }

    function _get(Object memory obj) internal view returns (TokenStats memory) {
        return stats[obj._address][obj._tokenId];
    }

    function _set(Object memory obj, TokenStats memory _stats) internal {
        stats[obj._address][obj._tokenId] = _stats;
    }

    function _random(address _contract, uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        return
            uint256(
                keccak256(abi.encodePacked(block.coinbase, _contract, tokenId))
            );
    }
}
