// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "./LockableERC20Guild.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/*
  @title DXDGuild
  @author github:AugustoL
  @dev An ERC20Guild for the DXD token designed to execute votes on Genesis Protocol Voting Machine.
*/
contract DXDGuild is LockableERC20Guild, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    // @dev Initilizer
    // @param _token The ERC20 token that will be used as source of voting power
    // @param _proposalTime The amount of time in seconds that a proposal will be active for voting
    // @param _timeForExecution The amount of time in seconds that a proposal action will have to execute successfully
    // @param _votingPowerForProposalExecution The percentage of voting power in base 10000 needed to execute a proposal
    // action
    // @param _votingPowerForProposalCreation The percentage of voting power in base 10000 needed to create a proposal
    // @param _name The name of the ERC20Guild
    // @param _voteGas The amount of gas in wei unit used for vote refunds
    // @param _maxGasPrice The maximum gas price used for vote refunds
    // @param _maxActiveProposals The maximum amount of proposals to be active at the same time
    // @param _permissionRegistry The address of the permission registry contract to be used
    // @param _lockTime The minimum amount of seconds that the tokens would be locked
    // @param _votingMachine The voting machine where the guild will vote
    function initialize(
        address _token,
        uint256 _proposalTime,
        uint256 _timeForExecution,
        uint256 _votingPowerForProposalExecution,
        uint256 _votingPowerForProposalCreation,
        uint256 _voteGas,
        uint256 _maxGasPrice,
        uint256 _maxActiveProposals,
        address _permissionRegistry,
        uint256 _lockTime,
        address _votingMachine
    ) public initializer {
        require(
            address(_token) != address(0),
            "ERC20Guild: token is the zero address"
        );
        _initialize(
            _token,
            _proposalTime,
            _timeForExecution,
            _votingPowerForProposalExecution,
            _votingPowerForProposalCreation,
            "DXDGuild",
            _voteGas,
            _maxGasPrice,
            _maxActiveProposals,
            _permissionRegistry
        );
        tokenVault = new TokenVault();
        tokenVault.initialize(address(token), address(this));
        lockTime = _lockTime;
        permissionRegistry.setPermission(
            address(0),
            address(this),
            bytes4(keccak256("setLockTime(uint256)")),
            0,
            true
        );
        permissionRegistry.setPermission(
            address(0),
            _votingMachine,
            bytes4(keccak256("vote(bytes32,uint256,uint256,address)")),
            0,
            true
        );
        initialized = true;
    }
}
