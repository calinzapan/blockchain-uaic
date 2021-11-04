// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <=0.8.7;

contract DistributeFunding {
    uint private remainingQuota;
    event ReceivedFunds(address, uint);
    
    struct beneficiary {
        address beneficiaryAddress;
        uint quota;
    }
    
    mapping(address => uint) beneficiaries;
    
    address[] beneficiariesKeys;
    constructor() {
        remainingQuota = 100;
    }
    
    
    function addBeneficiary(address beneficiaryAddress, uint beneficiaryQuota) public {
        require(beneficiaryQuota <= remainingQuota);
        beneficiaries[beneficiaryAddress] = beneficiaryQuota;
        beneficiariesKeys.push(beneficiaryAddress);
    }
    
    function distributeFunds() public payable {
        for(uint i = 0; i < beneficiariesKeys.length; i++) {
            payable(beneficiariesKeys[i]).transfer(address(this).balance * beneficiaries[beneficiariesKeys[i]] / 100);
        }
    }
    
     receive() external payable { 
        emit ReceivedFunds(msg.sender, msg.value);
    }
    
    function getBalance() view public returns (uint) {
      return address(this).balance;
    }
    
    function getBeneficiaries() view public returns (address[] memory) {
        return beneficiariesKeys;
    }
}

contract Crowdfunding {
    address owner;
    uint public fundingGoal;
    uint internal totalRaised = 0;
    uint sponsorFunds;
    DistributeFunding distributeFundingContract;
    SponsorFunding sponsorContract;
    
    mapping (address => uint) contributors; // variabila de tip mapping
    
    event CompletedRefund(address, uint);
    event ReceivedFunds(address, uint);
    
    modifier onlyOwner() { 
        require(owner == msg.sender,"Only Owner Allowed." ); 
        _; 
    } 
    
    modifier inProgress() {
        require(totalRaised + sponsorFunds < fundingGoal);
        _;
    }
    
    modifier completedCampaign() {
        require(totalRaised + sponsorFunds >= fundingGoal);
        _;
    }
    
    constructor(uint _goal, address _distributionAddress, address _sponsorAddress) {
        owner = msg.sender;
        fundingGoal = _goal;
        distributeFundingContract = DistributeFunding(payable(_distributionAddress));
        sponsorContract = SponsorFunding(payable(_sponsorAddress));
        sponsorFunds = fundingGoal * sponsorContract.sponsorship() / 100;
    }
    
    function fund() public inProgress payable {
        contributors[msg.sender] += msg.value;
        totalRaised += msg.value;
        
        if(totalRaised + sponsorFunds >= fundingGoal) {
            sponsorContract.requestSponsorFunds();
        }
    }
    
    function refund(uint amount) public inProgress payable {
        require(amount <= contributors[msg.sender]);
        contributors[msg.sender] -= amount;
        totalRaised -= amount;
        payable(msg.sender).transfer(amount);
        emit CompletedRefund(msg.sender, amount);
    }
    
    
    receive() external payable { 
        emit ReceivedFunds(msg.sender, msg.value);
    }
    
    function getBalance() view public onlyOwner returns (uint) {
      return address(this).balance;
    }
    
    function getRemaining() view public returns(uint) {
        if(address(this).balance > fundingGoal) {
            return 0;
        }
        return fundingGoal - address(this).balance;
        
    }
    
    
    function sendFundsToDistribution() public onlyOwner completedCampaign {
        distributeFundingContract.distributeFunds{value: address(this).balance}();
    }
}

contract SponsorFunding {
    uint public sponsorship;
    event ReceivedFunds(address, uint);
    
    constructor(uint _sponsorship) payable {
        require(sponsorship < 100);
        sponsorship = _sponsorship;
    }
    
    function requestSponsorFunds() external {
        Crowdfunding projectContract = Crowdfunding(payable(msg.sender));
        uint sponsorFunds = projectContract.fundingGoal() * sponsorship / 100;
        require(projectContract.getBalance() + sponsorFunds >= projectContract.fundingGoal());
        payable(projectContract).transfer(sponsorFunds);
    }
    
    receive() external payable { 
        emit ReceivedFunds(msg.sender, msg.value);
    }
}
