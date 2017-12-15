pragma solidity ^0.4.2;

contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData); }

contract token {
    /* Public variables of the token */
    string public standard = 'Token 0.1';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public releasedSupply;
    uint256 initialRelease;
    uint256 releaseCount;
    uint minReleaseCycle;
    uint maxReleaseCycle;
    uint lastReleaseTime;
    address owner;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function token(
        uint256 initialSupply,
        uint256 initReleasedSupply,
        string tokenName,
        uint8 decimalUnits,
        string tokenSymbol
        ) {
        require(releasedSupply < initialSupply);
        owner = msg.sender;
        balanceOf[msg.sender] = initReleasedSupply;
        totalSupply = initialSupply;
        releasedSupply = initReleasedSupply;
        name = tokenName;
        symbol = tokenSymbol;
        decimals = decimalUnits;
        lastReleaseTime = now;
        releaseCount = 0;
    }

    /* Send coins */
    function transfer(address _to, uint256 _value) {
        require(balanceOf[msg.sender] >= _value);           // Check if the sender has enough
        require(balanceOf[_to] + _value >= balanceOf[_to]); // Check for overflows
        balanceOf[msg.sender] -= _value;                     // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        Transfer(msg.sender, _to, _value);                   // Notify anyone listening that this transfer took place
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value)
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /* Approve and then communicate the approved contract in a single tx */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        require(balanceOf[_from] >= _value);                 // Check if the sender has enough
        require(balanceOf[_to] + _value >= balanceOf[_to]);  // Check for overflows
        require(_value <= allowance[_from][msg.sender]);   // Check allowance
        balanceOf[_from] -= _value;                          // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        allowance[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }

    /* This unnamed function is called whenever someone tries to send ether to it */
    function () {
        return;     // Prevents accidental sending of ether
    }
}

// Ŀ
contract CDNToken is owned, token {

    uint256 public sellPrice;
    uint256 public buyPrice;

    mapping (address => bool) public frozenAccount;

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CDNToken(
        uint256 initialSupply,
        uint256 initReleasedSupply,
        string tokenName,
        uint8 decimalUnits,
        string tokenSymbol
    ) token (initialSupply, initReleasedSupply, tokenName, decimalUnits, tokenSymbol) {}

    /* Send coins */
    function transfer(address _to, uint256 _value) {
        require(balanceOf[msg.sender] >= _value);           // Check if the sender has enough
        require(balanceOf[_to] + _value >= balanceOf[_to]); // Check for overflows
        require(!frozenAccount[msg.sender]);                // Check if frozen
        balanceOf[msg.sender] -= _value;                     // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        Transfer(msg.sender, _to, _value);                   // Notify anyone listening that this transfer took place
    }


    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        require(!frozenAccount[_from]);                        // Check if frozen
        require(balanceOf[_from] >= _value);                 // Check if the sender has enough
        require(balanceOf[_to] + _value >= balanceOf[_to]);  // Check for overflows
        require(_value <= allowance[_from][msg.sender]);   // Check allowance
        balanceOf[_from] -= _value;                          // Subtract from the sender
        balanceOf[_to] += _value;                            // Add the same to the recipient
        allowance[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }

//    function mintToken(address target, uint256 mintedAmount) onlyOwner {
//        balanceOf[target] += mintedAmount;
//        totalSupply += mintedAmount;
//        Transfer(0, this, mintedAmount);
//        Transfer(this, target, mintedAmount);
//    }

    function freezeAccount(address target, bool freeze) onlyOwner {
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }

    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }

    function buy() payable {
        uint amount = msg.value / buyPrice;                // calculates the amount
        require(balanceOf[this] >= amount);               // checks if it has enough to sell
        balanceOf[msg.sender] += amount;                   // adds the amount to buyer's balance
        balanceOf[this] -= amount;                         // subtracts amount from seller's balance
        Transfer(this, msg.sender, amount);                // execute an event reflecting the change
    }

    function sell(uint256 amount) {
        require(balanceOf[msg.sender] >= amount );        // checks if the sender has enough to sell
        balanceOf[this] += amount;                         // adds the amount to owner's balance
        balanceOf[msg.sender] -= amount;                   // subtracts the amount from seller's balance
        require(msg.sender.send(amount * sellPrice));
        Transfer(msg.sender, this, amount);            // executes an event reflecting on the change
    }

    function releaseSupply(uint256 amount) {
        require(msg.sender == owner);
        // require(judgeOnTime());
        uint256 limit = getReleaseLimit();
        uint256 releaseAmount = amount * 100000000;
        if (releaseAmount > limit) {
            if (releasedSupply + limit > totalSupply) {
                balanceOf[owner] += totalSupply - releasedSupply;
                releasedSupply = totalSupply;
            } else {
                balanceOf[owner] += limit;
                releasedSupply += limit;
            }
        } else {
            if (releasedSupply + releaseAmount > totalSupply) {
                balanceOf[owner] += totalSupply - releasedSupply;
                releasedSupply = totalSupply;
            } else {
                balanceOf[owner] += releaseAmount;
                releasedSupply += releaseAmount;
            }
        }
        releaseCount += 1;
    }

    function releaseSupplyLinear(uint256 amount) {
        require(msg.sender == owner);
        // require(judgeOnTime());
        uint256 limit = 2000000;
        uint256 releaseAmount = amount * 100000000;
        if (releaseAmount + releasedSupply > initialRelease + (releaseCount + 1) * limit ) {
            if (releasedSupply + releaseAmount > totalSupply) {
                balanceOf[owner] += totalSupply - releasedSupply;
                releasedSupply = totalSupply;
            } else {
                balanceOf[owner] += initialRelease + (releaseCount + 1) * limit - releasedSupply;
                releasedSupply += initialRelease + (releaseCount + 1) * limit;
            }
        } else {
            if (releasedSupply + releaseAmount > totalSupply) {
                balanceOf[owner] += totalSupply - releasedSupply;
                releasedSupply = totalSupply;
            } else {
                balanceOf[owner] += releaseAmount;
                releasedSupply += releaseAmount;
            }   
        }
        releaseCount += 1;
    }

    function judgeOnTime() returns (bool onTime) {
        uint earlyTime = lastReleaseTime + minReleaseCycle * 1 days;
        uint lateTime = lastReleaseTime + maxReleaseCycle * 1 days;
        while (now > lateTime) {
            lastReleaseTime += minReleaseCycle * 1 days;
            earlyTime = lastReleaseTime + minReleaseCycle * 1 days;
            lateTime = lastReleaseTime + maxReleaseCycle * 1 days;
        }
        if (now >= earlyTime && now < lateTime) {
            return true;
        } else {
            return false;
        }
    }

    function getReleaseLimit() returns (uint256 limit) {
        return (totalSupply - 27000000) / (12 * 5);
        // if (time > 120) {
        //  return 0
        // } else {
        //  return -(73 / 144) * (time - 120) * (time - 120) + 10000
        // }
        // return 1000;
    }
}

contract SaleLLC {

    address public benefitAddress;
    address public senderAccount;
    uint public fundingGoal;
    uint public amountRaised;
    uint public deadline;
    uint public price;
    CDNToken public tokenReward;
    mapping(address => uint256) public balanceOf;
    bool fundingGoalReached = false;
    bool crowdSaleClosed = false;
    event GoalReached(address benefitAddress, uint amountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);

    function SaleLLC(
        address ifSuccessSendToAddress,
        uint goal,
        uint durationInHours,
        uint weiCostOfEachToken,
        CDNToken addressOfTokenReward,
        address _senderAccount
    ) {
        benefitAddress = ifSuccessSendToAddress;
        senderAccount = _senderAccount;
        fundingGoal = goal;
        deadline = now + durationInHours * 1 hours;
        price = weiCostOfEachToken * 0.000000000000000001 ether;
        tokenReward = CDNToken(addressOfTokenReward);
    }

    function () payable {
        uint amount = msg.value;
        balanceOf[msg.sender] = amount;
        amountRaised += amount;
        tokenReward.transferFrom(senderAccount ,msg.sender, 100000000 * amount / price);
        benefitAddress.transfer(amount);
        FundTransfer(msg.sender, amount, true);
    }
}