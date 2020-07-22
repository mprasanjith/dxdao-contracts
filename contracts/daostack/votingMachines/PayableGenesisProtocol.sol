pragma solidity ^0.5.11;

import "./GenesisProtocol.sol";

interface AvatarInterface {
    function nativeReputation() external view returns(address);
}

/**
 * @title GenesisProtocol implementation -an organization's voting machine scheme taht can pay for its vote gas costs.
 *
 * Allows all organization using the voting machine to send ETH that will eb used for paying a fraction or total gas 
 * costs when voting, each organization can set hwo much percentage of the gas spent pay back depending on how much 
 * rep the voter has.
 */
contract PayableGenesisProtocol is GenesisProtocol {

    struct OrganizationRefunds {
      uint256 balance;
      uint256 baseRefund; // In base 100, 10 == 10%
      uint256 premiumRefund; // In base 100, 10 == 10%
      uint256 repToPremiumRefund; // Rep amount of msg.sender to recieve premiumRefund.
    }
    
    mapping(address => OrganizationRefunds) organizationRefunds;
    mapping(bytes32 => address) organizationByOrganizationIds;
    
    /**
    * @dev enables an voting machine to receive ether
    */
    function() external payable {
      organizationRefunds[msg.sender].balance = organizationRefunds[msg.sender].balance.add(msg.value);
    }
    
    /**
    * @dev Config the refund for each daostack dao form 
    */
    function setOrganizationRefund(uint256 _baseRefund, uint256 _premiumRefund, uint256 _repToPremiumRefund) public {
      organizationRefunds[msg.sender].baseRefund = _baseRefund;
      organizationRefunds[msg.sender].premiumRefund = _premiumRefund;
      organizationRefunds[msg.sender].repToPremiumRefund = _repToPremiumRefund;
    }
    
    /**
     * @dev register a new proposal with the given parameters. Every proposal has a unique ID which is being
     * generated by calculating keccak256 of a incremented counter.
     *
     * Changed by PayableGenesisProtocol implementation to keep tarck of organization address for proposalId
     *
     * @param _paramsHash parameters hash
     * @param _proposer address
     * @param _organization address
     */
    function propose(uint256, bytes32 _paramsHash, address _proposer, address _organization)
        external
        returns(bytes32)
    {
      // solhint-disable-next-line not-rely-on-time
        require(now > parameters[_paramsHash].activationTime, "not active yet");
        //Check parameters existence.
        require(parameters[_paramsHash].queuedVoteRequiredPercentage >= 50);
        // Generate a unique ID:
        bytes32 proposalId = keccak256(abi.encodePacked(this, proposalsCnt));
        proposalsCnt = proposalsCnt.add(1);
         // Open proposal:
        Proposal memory proposal;
        proposal.callbacks = msg.sender;
        proposal.organizationId = keccak256(abi.encodePacked(msg.sender, _organization));
        
        // Added line by PayableGenesisProtocol implementation
        organizationByOrganizationIds[proposal.organizationId] = _organization;

        proposal.state = ProposalState.Queued;
        // solhint-disable-next-line not-rely-on-time
        proposal.times[0] = now;//submitted time
        proposal.currentBoostedVotePeriodLimit = parameters[_paramsHash].boostedVotePeriodLimit;
        proposal.proposer = _proposer;
        proposal.winningVote = NO;
        proposal.paramsHash = _paramsHash;
        if (organizations[proposal.organizationId] == address(0)) {
            if (_organization == address(0)) {
                organizations[proposal.organizationId] = msg.sender;
            } else {
                organizations[proposal.organizationId] = _organization;
            }
        }
        //calc dao bounty
        uint256 daoBounty =
        parameters[_paramsHash].daoBountyConst.mul(averagesDownstakesOfBoosted[proposal.organizationId]).div(100);
        proposal.daoBountyRemain = daoBounty.max(parameters[_paramsHash].minimumDaoBounty);
        proposals[proposalId] = proposal;
        proposals[proposalId].stakes[NO] = proposal.daoBountyRemain;//dao downstake on the proposal

        emit NewProposal(proposalId, organizations[proposal.organizationId], NUM_OF_CHOICES, _proposer, _paramsHash);
        return proposalId;
    }

    /**
     * @dev voting function
     *
     * Changed by PayableGenesisProtocol implementation to pay for gas spent in vote
     *
     * @param _proposalId id of the proposal
     * @param _vote NO(2) or YES(1).
     * @param _amount the reputation amount to vote with . if _amount == 0 it will use all voter reputation.
     * @param _voter voter address
     * @return bool true - the proposal has been executed
     *              false - otherwise.
     */
    function vote(bytes32 _proposalId, uint256 _vote, uint256 _amount, address _voter)
    external
    votable(_proposalId)
    returns(bool) {
        // Added line by PayableGenesisProtocol to keep track of gast spent
        uint256 gasSent = gasleft();
        
        Proposal storage proposal = proposals[_proposalId];
        Parameters memory params = parameters[proposal.paramsHash];
        address voter;
        if (params.voteOnBehalf != address(0)) {
            require(msg.sender == params.voteOnBehalf);
            voter = _voter;
        } else {
            voter = msg.sender;
        }
        bool voteResult = internalVote(_proposalId, voter, _vote, _amount);
        
        // Added section by PayableGenesisProtocol to pay for gas spent
        if (voteResult) {
            address organizationAddress = organizationByOrganizationIds[_proposalId];
            uint256 senderReputation = IERC20(
                AvatarInterface(organizationAddress).nativeReputation()
            ).balanceOf(msg.sender);
            uint256 gasSpent = gasSent.sub(gasleft());
            uint256 toSend = gasSpent.mul(100).div(organizationRefunds[organizationAddress].premiumRefund);
            if (senderReputation < organizationRefunds[organizationAddress].repToPremiumRefund) {
                toSend = gasSpent.mul(100).div(organizationRefunds[organizationAddress].baseRefund);
            }
            if (address(this).balance > toSend)
                msg.sender.transfer(toSend);
          }
    }

}
