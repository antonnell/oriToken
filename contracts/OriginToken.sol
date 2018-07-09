pragma solidity ^0.4.21;


import "./templates/SafeMath.sol";
import "./templates/ERC20Basic.sol";
import "./templates/BasicToken.sol";
import "./templates/Ownable.sol";
import "./templates/Pausable.sol";
import "./templates/BurnableToken.sol";
import "./templates/MintableToken.sol";
import "./templates/StakedToken.sol";
import "./templates/CrossChainToken.sol";
import "./templates/NotifyContract.sol";

/**
 * @title OriginToken
 * Ownable
 * Pausable
 * Burnable
 * Mintable
 * Stakeable
 * CrossChainable
 */
contract OriginToken is ERC20Basic, BasicToken, Ownable, Pausable, BurnableToken, MintableToken, StakedToken, CrossChainToken, NotifyContract {
    using SafeMath for uint256;

    string public constant name = "Origin";
    string public constant symbol = "XBO";
    uint8 public constant decimals = 18;

    address private foundationAddress = 0x0; //onlyOwner set. Address of the Origin Foundation
    address private ownerAddress; //owner of the contract

    uint256 private daysInYear = 365; //number of days in a year
    uint256 private blocksInADay = 6646; // Calculated as 1 block = 13 seconds, 24 (hours) * 60 (minutes) * 60 (seconds) / 13 (13 seconds per block)
    //uint256 private yearsUntilFullyDiluted = 2; //number of years until blockRewardSupply is depleted
    uint256 private forkedCoinSupply = 16000000000; //Forked coin supply
    uint256 private blockRewardSupply = 11000000000; //Block reward supply

    uint256 private btcPeggedPrice = 6300; //pegged on 2018/07/02 07:18 GMT+2
    uint256 private xboPeggedPrice = 5; //self pegged. NOTE** Divide by 100
    uint256 private maxAmbassadors = 20; // OnlyOwner configurable
    uint256 private ambassadorBlockRewardPercent = 5; //Rewards for Ambassador on sliding scale of 5% of total diluted per day
    uint256 private votingStakeRewardPercent = 25; //Proportionate to voting stake per day of 25% of total diluted per day
    uint256 private stakingRewardPercent = 70; //Proportionate distribution to stakers per day of 70% of total diluted per day

    uint256 private dilutionPerDay = blockRewardSupply.div(daysInYear.mul(2)); // Calculated as BlockRewardSupply 11,000,000,000 / (days in year (365) * years till fully diluted (2) )
    uint256 private dailyAmbassadorRewards = dilutionPerDay.mul(ambassadorBlockRewardPercent).div(100); // Calculated as dilution per day * block reward for ambassadors (5%)
    uint256 private perBlockAmbassadorRewards = dailyAmbassadorRewards.div(blocksInADay); //perBlockAmbassadorRewards = dailyAmbassadorRewards / blocksInADay
    uint256 private dailyStakingRewards = dilutionPerDay.mul(stakingRewardPercent).div(100); // Calculated as dilution per day * block reward for ambassadors (5%)

    uint256 private maxTotalDailyClaim = forkedCoinSupply.div(daysInYear.mul(2)); // Calculated Forked Coins Supply 16,000,000,000 / days in year (365) * years till fully diluted (2)
    uint256 private maxIndividualDailyClaim = btcPeggedPrice.mul(100).div(xboPeggedPrice).div(2); // Calculated as 1 BTC at $7427 and 1 XBO at $0.05 equals 148,540 XBO and max cap of 0.5 BTC
    uint256 private totalDailyClaimHitZeroBlock = 0; //onlyOwner set
    uint256 private totalDailyClaim = maxTotalDailyClaim; //onlyOwner set
    uint256 private dailyVoterDistribution = 753424; //TODO: Figure out calculation for this

    uint256 private maxFoundationTotalDailyClaim = forkedCoinSupply.div(daysInYear.mul(2)); // Calculated Forked Coins Supply 16,000,000,000 / days in year (365) * years till fully diluted (2)
    uint256 private totalFoundationDailyClaimHitZeroBlock = 0; //onlyOwner set
    uint256 private totalFoundationDailyClaim = maxFoundationTotalDailyClaim; //onlyOwner set
    uint256 private maxFoundationIndividualDailyClaim = btcPeggedPrice.mul(100).div(xboPeggedPrice).div(2); //Calculated as 1 BTC at $7427 and 1 XBO at $0.05 equals 148,540 XBO and max cap of 0.5 BTC

    bool public voteOpen = false;
    uint256 private totalVotes = 0;

    uint256 private blockVoterDistribution = dailyVoterDistribution.div(blocksInADay);

    // 365/12 = 30.42 days in a regular year and 366/12 = 30.50 days in a leap year
    //blocksInAMonth = 30.42 ∗ blocksInADay = 202171,32
    //uint256 private blocksInAMonth = blocksInADay.mul(daysInYear.div(12));
    //monthlyAmbassadorRewards = 30.42 ∗ dailyAmbassadorRewards = 22,919,178.15
    //uint256 private monthlyAmbassadorRewards = dailyAmbassadorRewards.mul(daysInYear.div(12));

    uint256 private currentBlock = block.number;

    uint256 private currentTotalStakeIndex = 0;


    uint256[] private ambassadorMonthlyRewardsByPosition; //onlyOwner set

    address[] private candidateListAddresses;
    address[] private votersAddresses;
    CurrentTotalStakesStruct[] private stakeHistory;


    mapping(address => ClaimStruct) private userClaimedBalances;

    mapping(address => CandidateStruct) private candidateList;
    mapping(address => VoterStruct) private voters;

    mapping(uint256 => AmbassadorStuct) private ambassadorList;

    mapping(address => CurrentUserStakesStruct) private currentUserStakes;
    mapping(address => UserStakeHistory[]) private userStakeHistory;

    struct ClaimStruct {
        bool canClaim;
        uint256 blockNumber;
        uint256 remainingDailyBalance;
        uint256 totalClaimedBalance;
        uint256 claimableBalance;
    }

    struct CandidateStruct {
       string name;
       string surname;
       string metadata;
       uint256 votes;
    }

    struct VoterStruct {
       uint256 block;
       uint256 votes;
       address voterAddress;
       bool voted;
    }

    struct AmbassadorStuct {
        address ambassadorAddress;
        uint256 blockStarted;
        uint256 totalVotes;
        uint256 rank;
    }

    struct UserStakeHistory {
        uint256 totalStakeIndex;
        uint256 userStake;
        uint256 userStakeBlock;
    }

    struct CurrentUserStakesStruct {
        uint256 stakeIndex;
        uint256 stake;
        uint256 stakeBlock;
    }

    struct CurrentTotalStakesStruct {
        uint256 currentTotalStakeIndex;
        uint256 currentTotalStake;
        uint256 currentTotalStakeBlock;
    }

    /**
     * Constrctor function
     *
     * Initializes token and sets the owner
     *
     * Initialises the ambassadorMonthlyRewardsByPosition
     */
    constructor() public {
        ownerAddress = msg.sender;

        ambassadorMonthlyRewardsByPosition.push(0);
        ambassadorMonthlyRewardsByPosition.push(20);
        ambassadorMonthlyRewardsByPosition.push(15);
        ambassadorMonthlyRewardsByPosition.push(10);
        ambassadorMonthlyRewardsByPosition.push(8);
        ambassadorMonthlyRewardsByPosition.push(8);
        ambassadorMonthlyRewardsByPosition.push(8);
        ambassadorMonthlyRewardsByPosition.push(5);
        ambassadorMonthlyRewardsByPosition.push(5);
        ambassadorMonthlyRewardsByPosition.push(5);
        ambassadorMonthlyRewardsByPosition.push(2);
        ambassadorMonthlyRewardsByPosition.push(2);
        ambassadorMonthlyRewardsByPosition.push(2);
        ambassadorMonthlyRewardsByPosition.push(2);
        ambassadorMonthlyRewardsByPosition.push(2);
        ambassadorMonthlyRewardsByPosition.push(1);
        ambassadorMonthlyRewardsByPosition.push(1);
        ambassadorMonthlyRewardsByPosition.push(1);
        ambassadorMonthlyRewardsByPosition.push(1);
        ambassadorMonthlyRewardsByPosition.push(1);
    }

    /**
     * onlyOwner validates
     *
     * that the incoming sender === owner
     */
    modifier onlyOwner() {
        require(msg.sender == ownerAddress);
        _;
    }

    /**
     * ownerOrFoundation validates
     *
     * that the incoming sender === owner
     */
    /*modifier ownerOrFoundation() {
        require(msg.sender == ownerAddress || msg.sender == foundationAddress);
        _;
    }*/

    /**
     * canClaim validates:
     *
     * canClaim == true
     *
     * claimableBalance > 0
     * remainingDailyBalance > 0
     * or
     * blockNumber > previous Claimed Block Number for the user + Blocks in a day
     *
     * contract remaining daily claim > 0
     * or
     * blok numbwe > contract claim block + blocks in a day
     */
    modifier canClaim() {
        require (userClaimedBalances[msg.sender].canClaim == true &&
        ((userClaimedBalances[msg.sender].remainingDailyBalance > 0 || userClaimedBalances[msg.sender].blockNumber.add(blocksInADay) <= block.number) && userClaimedBalances[msg.sender].claimableBalance > 0) &&
        (totalDailyClaim > 0 || totalDailyClaimHitZeroBlock.add(blocksInADay) <= block.number));
        _;
    }

    /**
     * canClaimFoundation validates:
     *
     * canClaim == true
     * remainingDailyBalance > 0
     * claimableBalance > 0
     *
     */
    /*modifier canClaimFoundation() {
        require (userClaimedBalances[msg.sender].canClaim == true &&
        ((userClaimedBalances[msg.sender].remainingDailyBalance > 0 &&
        userClaimedBalances[msg.sender].claimableBalance > 0) ||
        userClaimedBalances[msg.sender].blockNumber.add(blocksInADay) >= block.number) &&
        (totalFoundationDailyClaim > 0 ||
        totalFoundationDailyClaimHitZeroBlock.add(blocksInADay) >= block.number));
        _;
    }*/

    /**
     * onlyFoundation validates
     *
     * that the incoming address is the Origin Foundation's adddress
     */
    modifier onlyFoundation() {
        require(msg.sender == foundationAddress);
        _;
    }

    /**
     * canStartStaking validates
     *
     * that the address has balance to stake
     */
    modifier canStartStaking {
        require (balances[msg.sender] >= msg.value);
        _;
    }

    /**
     * canStopStaking validates
     *
     * that the address has staked amount
     */
    modifier canStopStaking {
        require (stakes[msg.sender] >= msg.value);
        /*  return (stakes[msg.sender] >= amount&&votes[msg.sender]);  */
        _;
    }

    /**
     * canVote validates
     *
     * that the addres has voted
     */
    modifier canVote() {
        require(voteOpen == true && voters[msg.sender].voted == false);
        _;
    }

    /**
     * isOpen validates
     *
     * that voting process is open
     */
    modifier isOpen() {
        require(voteOpen == true);
        _;
    }

    /**
     * isClosed validates
     *
     * that voting process is closed
     */
    modifier isClosed() {
        require(voteOpen == false);
        _;
    }

    //GETTERS AND SETTERS

    /*// returns ambassadorMonthlyRewardsByPosition at index position
    function getAmbassadorMonthlyRewardsByPosition(uint256 _position) public view returns(uint256) {
        return ambassadorMonthlyRewardsByPosition[_position];
    }
    // set the ambassadorMonthlyRewardsByPosition at position position to percent
    function setAmbassadorMonthlyRewardsByPosition(uint256 _position, uint256 _percent) public onlyOwner {
        ambassadorMonthlyRewardsByPosition[_position] = _percent;
    }

    // returns totalDailyClaimHitZeroBlock
    function getTotalDailyClaimHitZeroBlock() public view returns(uint256) {
        return totalDailyClaimHitZeroBlock;
    }
    // set the totalDailyClaimHitZeroBlock to _totalDailyClaimHitZeroBlock
    function setTotalDailyClaimHitZeroBlock(uint256 _totalDailyClaimHitZeroBlock) public onlyOwner {
        totalDailyClaimHitZeroBlock = _totalDailyClaimHitZeroBlock;
    }

    // returns totalDailyClaim
    function getTotalDailyClaim() public view returns(uint256) {
        return totalDailyClaim;
    }
    // set the totalDailyClaim to _totalDailyClaim
    function setTotalDailyClaim(uint256 _totalDailyClaim) public onlyOwner {
        totalDailyClaim = _totalDailyClaim;
    }

    // returns totalFoundationDailyClaimHitZeroBlock
    function getTotalFoundationDailyClaimHitZeroBlock() public view returns(uint256) {
        return totalFoundationDailyClaimHitZeroBlock;
    }
    // set the totalFoundationDailyClaimHitZeroBlock to _totalFoundationDailyClaimHitZeroBlock
    function setTotalFoundationDailyClaimHitZeroBlock(uint256 _totalFoundationDailyClaimHitZeroBlock) public onlyOwner {
        totalFoundationDailyClaimHitZeroBlock = _totalFoundationDailyClaimHitZeroBlock;
    }

    // returns totalFoundationDailyClaim
    function getTotalFoundationDailyClaim() public view returns(uint256) {
        return totalFoundationDailyClaim;
    }
    // set the totalFoundationDailyClaim to _totalFoundationDailyClaim
    function setTotalFoundationDailyClaim(uint256 _totalFoundationDailyClaim) public onlyOwner {
        totalFoundationDailyClaim = _totalFoundationDailyClaim;
    }*/

    // returns foundationAddress
    function getFoundationAddress() public view returns(address) {
        return foundationAddress;
    }
    // set the foundationAddress to _foundationAddress
    function setFoundationAddress(address _foundationAddress) public onlyOwner {
        foundationAddress = _foundationAddress;
    }

    /*// returns btcPeggedPrice
    function getBTCPeggedPrice() public view returns(uint256) {
        return btcPeggedPrice;
    }
    // set the btcPeggedPrice to _btcPeggedPrice
    function setBTCPeggedPrice(uint256 _btcPeggedPrice) public onlyOwner {
        btcPeggedPrice = _btcPeggedPrice;
    }

    // returns xboPeggedPrice
    function getXBOPeggedPrice() public view returns(uint256) {
        return xboPeggedPrice;
    }
    // sets the xboPeggedPrice to _xboPeggedPrice
    function setXBOPeggedPrice(uint256 _xboPeggedPrice) public onlyOwner {
        xboPeggedPrice = _xboPeggedPrice;
    }

    // returns maxAmbassadors
    function getMaxAmbassadors() public view returns(uint256) {
        return maxAmbassadors;
    }
    // sets the maxAmbassadors to _maxAmbassadors
    function setMaxAmbassadors(uint256 _maxAmbassadors) public onlyOwner {
        maxAmbassadors = _maxAmbassadors;
    }

    // returns ambassadorBlockRewardPercent
    function getAmbassadorBlockRewardPercent() public view returns(uint256) {
        return ambassadorBlockRewardPercent;
    }
    // sets the ambassadorBlockRewardPercent to _ambassadorBlockRewardPercent
    function setAmbassadorBlockRewardPercent(uint256 _ambassadorBlockRewardPercent) public onlyOwner {
        ambassadorBlockRewardPercent = _ambassadorBlockRewardPercent;
    }

    // returns votingStakeRewardPercent
    function getVotingStakeRewardPercent() public view returns(uint256) {
        return votingStakeRewardPercent;
    }
    // sets the votingStakeRewardPercent to _votingStakeRewardPercent
    function setVotingStakeRewardPercent(uint256 _votingStakeRewardPercent) public onlyOwner {
        votingStakeRewardPercent = _votingStakeRewardPercent;
    }

    // returns stakingRewardPercent
    function getStakingRewardPercent() public view returns(uint256) {
        return stakingRewardPercent;
    }
    // sets the stakingRewardPercent to _stakingRewardPercent
    function setStakingRewardPercent(uint256 _stakingRewardPercent) public onlyOwner {
        stakingRewardPercent = _stakingRewardPercent;
    }*/

    /**
     * @dev returns claimableBalance for address _claimAddress
     *
     * @param: address _claimAddress the address to look up
     *
     * @returns the claimable balance attaached to teh address _claimAddress
     */
    function getClaimableBalance(address _claimAddress) public view returns(uint256) {
        return userClaimedBalances[_claimAddress].claimableBalance;
    }
    /**
     * @dev sets the claimableBalance at address claimAddress to claimableBalance
     *
     * @param: address _claimAddress the address to set
     * @param: uint256 _claimableBalance the balance to set
     *
     * @returns the claimable balance attaached to teh address _claimAddress
     */
    function setClaimableBalance(address _claimAddress, uint256 _claimableBalance) public onlyOwner {
        userClaimedBalances[_claimAddress].claimableBalance = _claimableBalance;
    }

    /** @dev create a new claimer address _claimerAddress with claimer balance set to _claimerBalance
     *
     * @param: address _claimAddress (the address who will be claiming the token)
     * @param: uint256 _claimableBalance (the total amount that the address can claim)
     *
     * TODO: Figure out a way to make the address claimableBalance additive, not fixed.
     */
    function createNewClaimer(address _claimAddress, uint256 _claimableBalance) public onlyOwner {
        userClaimedBalances[_claimAddress] = ClaimStruct({
            canClaim: true,
            blockNumber: 0,
            remainingDailyBalance: maxIndividualDailyClaim,
            totalClaimedBalance: 0,
            claimableBalance: _claimableBalance
        });
    }

    function getCandidateList(uint256 _index) public view returns(string name, string surname, string metadata, uint256 votes) {
        require(candidateListAddresses.length > _index);
        // copy the data into memory
        CandidateStruct memory c = candidateList[candidateListAddresses[_index]];

        // break the struct's members out into a tuple
        // in the same order that they appear in the struct
        return (c.name, c.surname, c.metadata, c.votes);
    }

    function getAmbassadorList(uint256 _index) public view returns(address ambassadorAddress, uint256 blockStarted, uint256 totalVotes, uint256 rank) {
        // copy the data into memory
        AmbassadorStuct memory a = ambassadorList[_index];

        // break the struct's members out into a tuple
        // in the same order that they appear in the struct
        return (a.ambassadorAddress, a.blockStarted, a.totalVotes, a.rank);
    }


    /** FEATURE 1: CLAIMING:
     *
     * Claiming allows user to claim XBO tokens on a daily basis.
     * Claimers have to fetch their tokens, tokens will not be automatically airdropped to users
     * Claimers can fetch up to a maximum of their USD (fixed at fork date) value of BTC, ETH, BCH, LTC, and DASH (set in userClaimedBalances[address].claimableBalance)
     *
     * To illustrate, if a user has 1 of each BTC, ETH, BCH, LTC, and DASH at current value it would be;
     * 1 x BTC ($7427) + 1 x ETH ($587) + 1 x BCH ($1070) + 1 x LTC ($117) + 1 x DASH ($311)
     * $9512 / $0.05 (expected trade value of XBO)
     * 190,240 XBO
     * So the maximum amount of tokens claimable will be 190,240.
     *
     * Claimers can fetch up to a daily maximum of x, where x is assumed to be an XBO value equivalent to 0.5
     * BTC, and x being configurable by OnlyOwner.
     * 1 BTC = 190,240 XBO, so 0.5 would be 74,270
     *
     * At maximum claim ratio this would allow for;
     * 295 people @ 0.5 BTC max that can claim
     *
     * Claimers will need to register for an Origin wallet. This wallet will be a web interface. After they have logged
     * in they will be able to claim tokens. This will require ETH in their wallet to initiate the claim process.
     *
     */


    /**
     * @param: claim XBO tokens daily
     *
     * checks whether the clalimer is the Origin foundation address or not
     * checks the total claimed amount for the contract
     * checks the total claimed amount for the address
     * based on those, we mint the required number of tokens for the address.
     *
     * @returns bool true/false if successful
     */
    function claim() public canClaim returns (bool) {
        // Reset daily user block limit on a per user basis
        if (userClaimedBalances[msg.sender].blockNumber.add(blocksInADay) >= block.number) {
            userClaimedBalances[msg.sender].blockNumber = block.number;
            if(msg.sender == foundationAddress) {
                userClaimedBalances[msg.sender].remainingDailyBalance = maxFoundationIndividualDailyClaim;
            } else {
                userClaimedBalances[msg.sender].remainingDailyBalance = maxIndividualDailyClaim;
            }
        }

        // Reset total daily block limit for all users if true
        if(msg.sender == foundationAddress) {
            if (totalFoundationDailyClaimHitZeroBlock.add(blocksInADay) >= block.number) {
                totalFoundationDailyClaimHitZeroBlock = block.number;
                totalFoundationDailyClaim = maxFoundationTotalDailyClaim;
            }
        } else {
            if (totalDailyClaimHitZeroBlock.add(blocksInADay) >= block.number) {
                //TODO: this might skip a couple of blocks. Would it not be better to do something along the lines of totalDailyClaimHitZeroBlock = totalDailyClaimHitZeroBlock.add(blocksInADay);
                //      ie. always increment it by 1 day? What happens if nobody claims in a day then?
                //          maybe uint256 days = (block.numebr-totalDailyClaimHitZeroBlock).div(blocksInADay);
                //          if (days >= 1) { totalDailyClaimHitZeroBlock.add(blocksInADay.mul(days)); totalDailyClaim = maxTotalDailyClaim; }
                //      same logic applies to the check above
                totalDailyClaimHitZeroBlock = block.number;
                totalDailyClaim = maxTotalDailyClaim;
            }
        }

        //Base potential claim amount calculated as claimable balance (value left over from total claimable balance) − totalClaimed so far
        uint256 claimableAmount = userClaimedBalances[msg.sender].claimableBalance.sub(userClaimedBalances[msg.sender].totalClaimedBalance);

        // First limiter checks user daily remaining balance
        if (claimableAmount > userClaimedBalances[msg.sender].remainingDailyBalance) {
            claimableAmount = userClaimedBalances[msg.sender].remainingDailyBalance;
        }

        // Second limiter checks total daily limit
        if(msg.sender == foundationAddress) {
            if (claimableAmount > totalFoundationDailyClaim) {
                claimableAmount = totalFoundationDailyClaim;
            }
        } else {
            if (claimableAmount > totalDailyClaim) {
                claimableAmount = totalDailyClaim;
            }
        }

        // We have a claimable amount
        if (claimableAmount > 0) {
            if(msg.sender == foundationAddress) {
                totalFoundationDailyClaim = totalFoundationDailyClaim.sub(claimableAmount);
            } else {
                totalDailyClaim = totalDailyClaim.sub(claimableAmount);
            }

            userClaimedBalances[msg.sender].remainingDailyBalance = userClaimedBalances[msg.sender].remainingDailyBalance.sub(claimableAmount);
            userClaimedBalances[msg.sender].totalClaimedBalance = userClaimedBalances[msg.sender].totalClaimedBalance.add(claimableAmount);

            if (userClaimedBalances[msg.sender].totalClaimedBalance == userClaimedBalances[msg.sender].claimableBalance) {
                userClaimedBalances[msg.sender].canClaim = false;
            }

            mint(msg.sender, claimableAmount);

            return true;
        } else {
            // What conditions do we hit this on?
            return false;
        }
    }


    /** FEATURE 2: STAKING
     *
     * Staking allows user to stake their active funds. This will move funds from their current balances = address
     * => uint256 to the staking balance stakes = address => uint256.
     *
     * Staking will not mint net tokens unless actively withdrawn or staking more tokens.
     * Stake will be added to the balances pool, not the staked pool.
     * Stake is not passively distributed.
     * Stake needs to be actively withdrawn by the user.
     *
     *
     *
     */
    /*function calculateReward() internal view returns(uint256) {
        if(userStakeHistory[msg.sender].length == 0 || stakeHistory.length == 0) {
            return 0;
        }
        uint256 userStakeI = userStakeHistory[msg.sender].length.sub(1);
        uint256 totalStakeI = stakeHistory.length.sub(1);

        uint256 stakeRatio = 0;
        uint256 blocksStakedFor = 0;
        uint256 reward = 0;
        uint256 stakeReward = 0;

        if(userStakeI >= 0) {
          uint256 calculationCurrentBlock = currentBlock;
          uint256 calculationPreviousBlock = stakeHistory[totalStakeI].currentTotalStakeBlock;
          uint256 calculationPreviousBlockStake = stakeHistory[totalStakeI].currentTotalStake;
          uint256 calculationUserStakeBlock = userStakeHistory[msg.sender][userStakeI].userStakeBlock;

          //calculate stake from current block to last stake entry
          while (totalStakeI > 0 && calculationPreviousBlock >= calculationUserStakeBlock) {
            //do the stake reward calculation
            if(calculationPreviousBlockStake > 0 && calculationPreviousBlock > 0) {
                stakeRatio = userStakeHistory[msg.sender][userStakeI].userStake.div(calculationPreviousBlockStake);
                blocksStakedFor = calculationCurrentBlock.sub(calculationPreviousBlock);
                reward = blocksStakedFor.div(blocksInADay).mul(stakeRatio).mul(dailyStakingRewards);
                stakeReward = stakeReward.add(reward);
            }

            calculationCurrentBlock = stakeHistory[totalStakeI].currentTotalStakeBlock;

            totalStakeI = totalStakeI.sub(1);

            calculationPreviousBlock = stakeHistory[totalStakeI].currentTotalStakeBlock;
            calculationPreviousBlockStake = stakeHistory[totalStakeI].currentTotalStake;
          }
        }

        return stakeReward;
    }*/

    /**
     * stakes a portion of the tokens for an address
     *
     * every time that an address startsStaking, we mint the tokens for the staking rewards.
     * increment the current user's stake
     * increment the total stake amount
     *
     * subtract from the user's balance
     * increment the stakes amount
     *
     */
    function startStaking(uint256 _amount) public canStartStaking {

        //mint(msg.sender, calculateReward());

        // perform the stake. Should we use the StakedToken.sol stake function?
        _stake(msg.sender, _amount);

        //currentTotalStake = currentTotalStake.add(_amount);
        currentTotalStakeIndex = currentTotalStakeIndex.add(1);

        // get the addresses previous stake entry
        CurrentUserStakesStruct storage currentStakeStruct = currentUserStakes[msg.sender];

        // create a new stake struct
        CurrentUserStakesStruct memory currentUserStakesStruct = CurrentUserStakesStruct({
            stakeIndex: currentStakeStruct.stakeIndex.add(1),
            stake: currentStakeStruct.stake.add(_amount),
            stakeBlock: block.number
        });

        currentUserStakes[msg.sender] = currentUserStakesStruct;

        // add the values to the userStakeHistory and stakeHistroy
        userStakeHistory[msg.sender].push(UserStakeHistory({
            totalStakeIndex: currentUserStakesStruct.stakeIndex,
            userStake: currentUserStakesStruct.stake,
            userStakeBlock: block.number
        }));

        stakeHistory.push(CurrentTotalStakesStruct({
            currentTotalStakeIndex: currentTotalStakeIndex,
            currentTotalStake: stakedSupply_,
            currentTotalStakeBlock: block.number
        }));
    }

    /**
     * stops staking a portion of the tokens for an address
     *
     * every time that an address stopsStaking, we mint the tokens for the staking rewards.
     * subtract from the current user's stake
     * subtract from the total stake amount
     *
     * increment the user's balance
     * subtract from the stakes amount
     *
     */
    function stopStaking(uint256 _amount) public canStopStaking {
        //inverse of startsStaking
        //mint(msg.sender, calculateReward());

        // perform the stake. Should we use the StakedToken.sol stake function?
        _stopStaking(msg.sender, _amount);

        //currentTotalStake = currentTotalStake.sub(_amount);
        currentTotalStakeIndex = currentTotalStakeIndex.add(1);

        // get the addresses previous stake amount
        CurrentUserStakesStruct storage currentStakeStruct = currentUserStakes[msg.sender];

        // create a new stake struct
        CurrentUserStakesStruct memory currentUserStakesStruct = CurrentUserStakesStruct({
            stakeIndex: currentStakeStruct.stakeIndex.add(1),
            stake: currentStakeStruct.stake.sub(_amount),
            stakeBlock: block.number
        });

        currentUserStakes[msg.sender] = currentUserStakesStruct;

        // add the values to the userStakeHistory and stakeHistroy
        userStakeHistory[msg.sender].push(UserStakeHistory({
            totalStakeIndex: currentUserStakesStruct.stakeIndex,
            userStake: currentUserStakesStruct.stake,
            userStakeBlock: block.number
        }));

        stakeHistory.push(CurrentTotalStakesStruct({
            currentTotalStakeIndex: currentTotalStakeIndex,
            currentTotalStake: stakedSupply_,
            currentTotalStakeBlock: block.number
        }));
    }


    /** FEATURE 3: VOTING
     *
     * Voting is designed to allow XBO holders to vote on a monthly* basis. Voters will receive rewards for
     * their votes. Voters can vote for candidates from the pre-configured candidates list. Voters vote in ambassadors
     *
     * Users vote equals their staked balance on a 1:1 ratio
     *
     */

    //Do this one at a time. Most likely.
    function addToCandidateList(address _address, string _name, string _surname, string _metadata) public onlyOwner {
        candidateList[_address] = CandidateStruct({
            name: _name,
            surname: _surname,
            metadata: _metadata,
            votes: 0
        });
        candidateListAddresses.push(_address);
    }

    /*function removeFromCandidateList(address _address) public onlyOwner {
        delete candidateList[_address];

        bool found = false;
        for (uint256 i = 0; i < candidateListAddresses.length-1; i++){
            if(candidateListAddresses[i] == _address) {
                found = true;
            }

            if(found) {
                candidateListAddresses[i] = candidateListAddresses[i+1];
            }
        }
        if(found) {
            delete candidateListAddresses[candidateListAddresses.length-1];
            //candidateListAddresses.length = candidateListAddresses.length.sub(1);
        }
    }*/

    function clearCandidateList() private {
        for(uint256 i = 0; i < candidateListAddresses.length; i++) {
            delete candidateList[candidateListAddresses[i]];
            delete candidateListAddresses[i];
        }
        candidateListAddresses.length = 0;
    }

    function startVote() public onlyOwner isClosed {
        resetVote();
        clearCandidateList();
        voteOpen = true;
        //voteOpenBlock = block.number;
    }

    function endVote() public onlyOwner isOpen {
        voteOpen = false;
        //voteCloseBlock = block.number;

        // Step 1: Reward Ambassadors for past month, always 1 month trailing
        //rewardAmbassadors();

        // standard quicksort, but on votes not on array index, array index for now for simplicity
        address[] memory sortedCandidateList = sortCandidates(candidateListAddresses);

        //populate 1:maxAmbassadors
        uint256 limit = (maxAmbassadors < sortedCandidateList.length) ? maxAmbassadors : sortedCandidateList.length;

        for(uint256 i = 0; i < limit; i++) {
            ambassadorList[i.add(1)] = AmbassadorStuct({
                ambassadorAddress: sortedCandidateList[i],
                blockStarted: block.number,
                totalVotes: candidateList[sortedCandidateList[i]].votes,
                rank: i.add(1)
            });
        }
    }

    function castVote(address _address) public canVote {
        voters[msg.sender].voted = true;
        voters[msg.sender].votes = getStake(msg.sender);
        candidateList[_address].votes = candidateList[_address].votes.add(getStake(msg.sender));
        votersAddresses.push(msg.sender);

        totalVotes = totalVotes.add(getStake(msg.sender));
    }

    function getStake(address _address) internal view returns(uint256) {
        return stakes[_address];
    }


    /** FEATURE 4: VOTING DISTRIBUTION
     *
     * Considerations
     *
     * Voting round reset triggers manually via Owner. Token distribution should also trigger manually along with reset.
     *
     * Reset vote, iterate through voters, for each voter calculate a) block when staking started and b) stake. Stake
     * is based on total voting stake at time of reset and not stake at time of stake
     *
     */
    function resetVote() private {
        for(uint256 i = 0; i < votersAddresses.length; i++) {

            //blocks = block.number − voters[i].block // How many total blocks
            //uint256 blocks = block.number.sub(voters[i].block);
            //ratio = votes / totalVotes // participation of total votes
            uint256 ratio = 0;
            if(totalVotes != 0) {
                ratio = voters[votersAddresses[i]].votes.div(totalVotes);
                //reward = ratio ∗ blockVoterDistribution
                uint256 reward = ratio.mul(blockVoterDistribution);
                mint(voters[votersAddresses[i]].voterAddress, reward);
            }

            voters[votersAddresses[i]].voted = false;
            voters[votersAddresses[i]].votes = 0;

            //do we want to change the index of all of them?
            delete votersAddresses[i];
        }

        totalVotes = 0;
}




    /** FEATURE 5: AMBASSADOR
     *
     * Ambassadors are voted in from the candidate list. Stakers can vote for candidates.
     *
     * List of ethereum addresses => meta data TBC to ambassadors
     *
     * List of Candidates (Managed by Owner)
     * Vote on List of Candidates (locks up stake)
     * Define list maximum (by Owner)
     * Voting rounds (monthly) - Reset by Owner
     *
     * Reset occurs - stake older than reset block are allowed to stopStaking if stake has vote active Voting stake
     * contributed at time of vote
     *
     */

    function sortCandidates(address[] _array) internal view returns(address[]) {
        for(uint256 i = 0; i < _array.length; i++) {
            for(uint256 j = 0; j < i; j++) {
                if(candidateList[_array[j-1]].votes>candidateList[_array[j]].votes){
                    address temp = _array[j-1];
                    _array[j-1] = _array[j];
                    _array[j] = temp;
                }
            }
        }
        return _array;
    }

    /** FEATURE 6: AMBASSADOR REWARDS
     *
     *
     * Ambassador Reward Scheme
     *
     * 1. 20%
     * 2. 15%
     * 3. 10%
     * ...
     *
     */

    /*function rewardAmbassadors() private onlyOwner {
        for(uint256 i = 0; i < ambassadorMonthlyRewardsByPosition.length; i++) {
            uint256 reward = calculateRewardForAmbassador(i);
            mint(ambassadorList[i].ambassadorAddress, reward);
        }
    }

    function calculateRewardForAmbassador(uint256 i) private view returns(uint256) {
        return ambassadorMonthlyRewardsByPosition[i].div(100);
    }*/
}
