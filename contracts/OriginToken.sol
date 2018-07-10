pragma solidity ^0.4.21;


import "./templates/SafeMath.sol";
import "./templates/Pausable.sol";
import "./templates/BurnableToken.sol";
import "./templates/MintableToken.sol";
import "./templates/StakedToken.sol";
import "./templates/CrossChainToken.sol";
import "./templates/NotifyContract.sol";

/**
 * @title OriginToken
 *
 * Ownable
 * Pausable
 * Burnable
 * Mintable
 * Stakeable
 * CrossChainable
 */
contract OriginToken is Pausable, BurnableToken, MintableToken, StakedToken, CrossChainToken, NotifyContract {
    using SafeMath for uint256;

    string public constant name = "Origin";
    string public constant symbol = "XBO";
    uint8 public constant decimals = 18;

    uint256 private blocksInADay = 6646; // Calculated as 1 block = 13 seconds, 24 (hours) * 60 (minutes) * 60 (seconds) / 13 (13 seconds per block)
    uint256 private forkedCoinSupply = 16000000000; //Forked coin supply
    uint256 private blockRewardSupply = 11000000000; //Block reward supply

    uint256 private btcPeggedPrice = 6300; //pegged on 2018/07/02 07:18 GMT+2
    uint256 private xboPeggedPrice = 5; //self pegged. NOTE** Divide by 100
    uint256 private maxAmbassadors = 20; // OnlyOwner configurable
    uint256 private ambassadorBlockRewardPercent = 5; //Rewards for Ambassador on sliding scale of 5% of total diluted per day
    uint256 private votingStakeRewardPercent = 25; //TODO: USE THIS value Proportionate to voting stake per day of 25% of total diluted per day
    uint256 private stakingRewardPercent = 70; //Proportionate distribution to stakers per day of 70% of total diluted per day

    uint256 private dilutionPerDay = blockRewardSupply.div(730); // Calculated as BlockRewardSupply 11,000,000,000 / (days in year (365) * years till fully diluted (2) )
    uint256 private dailyAmbassadorRewards = dilutionPerDay.mul(ambassadorBlockRewardPercent).div(100); // Calculated as dilution per day * block reward for ambassadors (5%)
    //uint256 private perBlockAmbassadorRewards = dailyAmbassadorRewards.div(blocksInADay); //TODO: USE THIS. perBlockAmbassadorRewards = dailyAmbassadorRewards / blocksInADay
    uint256 private dailyStakingRewards = dilutionPerDay.mul(stakingRewardPercent).div(100); // Calculated as dilution per day * block reward for ambassadors (5%) 10 547 945

    uint256 private maxIndividualDailyClaim = btcPeggedPrice.mul(100).div(xboPeggedPrice).div(2); // Calculated as 1 BTC at $7427 and 1 XBO at $0.05 equals 148,540 XBO and max cap of 0.5 BTC
    uint256 private totalDailyClaimHitZeroBlock = 0; //onlyOwner set
    uint256 private totalDailyClaim = forkedCoinSupply.div(730); //onlyOwner set
    uint256 private dailyVoterDistribution = dilutionPerDay.mul(votingStakeRewardPercent).div(100); //TODO: Figure out calculation for this

    uint256 private totalFoundationDailyClaimHitZeroBlock = 0; //onlyOwner set
    uint256 private totalFoundationDailyClaim = forkedCoinSupply.div(730); //onlyOwner set
    uint256 private maxFoundationIndividualDailyClaim = btcPeggedPrice.mul(100).div(xboPeggedPrice).div(2); //Calculated as 1 BTC at $7427 and 1 XBO at $0.05 equals 148,540 XBO and max cap of 0.5 BTC

    bool private voteOpen = false;
    uint256 private totalVotes = 0;

    uint256 private currentTotalStakeIndex = 0;

    mapping(uint256 => uint256) private ambassadorMonthlyRewardsByPosition; //onlyOwner set
    mapping(uint256 => address) private candidateListAddresses;  //onlyOwner set
    uint256 candidateListAddressesLength = 0;
    mapping(uint256 => address) private votersAddresses;
    uint256 votersAddressesLength = 0;
    mapping(uint256 => CurrentTotalStakesStruct) private stakeHistory;
    uint256 stakeHistoryLength = 0;
    mapping(uint256 => AmbassadorStuct) private ambassadorList;
    uint256 ambassadorListLength = 0;

    mapping(address => ClaimStruct) private userClaimedBalances;
    mapping(address => CandidateStruct) private candidateList; //onlyOwner set
    mapping(address => VoterStruct) private voters;
    mapping(address => CurrentUserStakesStruct) private currentUserStakes;
    mapping(address => UserStakeHistoryStruct[]) private userStakeHistory;

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
       address candidateAddress;
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

    struct UserStakeHistoryStruct {
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
     * @dev Constrctor function
     *
     * Initializes token and sets the owner
     * Initialises the ambassadorMonthlyRewardsByPosition
     */
    constructor() public {
        ambassadorMonthlyRewardsByPosition[0] = 20;
        ambassadorMonthlyRewardsByPosition[1] = 15;
        ambassadorMonthlyRewardsByPosition[2] = 10;
        ambassadorMonthlyRewardsByPosition[3] = 8;
        ambassadorMonthlyRewardsByPosition[4] = 8;
        ambassadorMonthlyRewardsByPosition[5] = 8;
        ambassadorMonthlyRewardsByPosition[6] = 5;
        ambassadorMonthlyRewardsByPosition[7] = 5;
        ambassadorMonthlyRewardsByPosition[8] = 5;
        ambassadorMonthlyRewardsByPosition[9] = 2;
        ambassadorMonthlyRewardsByPosition[10] = 2;
        ambassadorMonthlyRewardsByPosition[11] = 2;
        ambassadorMonthlyRewardsByPosition[12] = 2;
        ambassadorMonthlyRewardsByPosition[13] = 2;
        ambassadorMonthlyRewardsByPosition[14] = 1;
        ambassadorMonthlyRewardsByPosition[15] = 1;
        ambassadorMonthlyRewardsByPosition[16] = 1;
        ambassadorMonthlyRewardsByPosition[17] = 1;
        ambassadorMonthlyRewardsByPosition[18] = 1;
        ambassadorMonthlyRewardsByPosition[19] = 1;
    }

    /**
     * @dev canClaim validates that canClaim == true and (claimableBalance > 0, current Users's remainingDailyBalance > 0) or (blockNumber > previous claimed block) and (remainingDailyBalance > 0 or we are on a new day)
     *
     */
    modifier canClaim() {
        require (userClaimedBalances[msg.sender].canClaim == true &&
        ((userClaimedBalances[msg.sender].remainingDailyBalance > 0 || userClaimedBalances[msg.sender].blockNumber.add(blocksInADay) <= block.number) && userClaimedBalances[msg.sender].claimableBalance > 0) &&
        (totalDailyClaim > 0 || totalDailyClaimHitZeroBlock.add(blocksInADay) <= block.number));
        _;
    }

    /**
     * @dev canStartStaking validates that the address has balance to stake
     *
     */
    modifier canStartStaking {
        require (balances[msg.sender] >= msg.value);
        _;
    }

    /**
     * @dev canStopStaking validates that the address has staked amount
     *
     */
    modifier canStopStaking {
        require (stakes[msg.sender] >= msg.value);
        /*  return (stakes[msg.sender] >= amount&&votes[msg.sender]);  */
        _;
    }

    /**
     * @dev canVote validates that the addres has not voted and the voting process is open
     *
     */
    modifier canVote() {
        require(voteOpen == true && voters[msg.sender].voted == false);
        _;
    }

    /**
     * @dev isOpen validates that voting process is open
     *
     */
    modifier isOpen() {
        require(voteOpen == true);
        _;
    }

    /**
     * @dev isClosed validates that voting process is closed
     *
     */
    modifier isClosed() {
        require(voteOpen == false);
        _;
    }

    // returns ambassadorMonthlyRewardsByPosition at index position
    function getAmbassadorMonthlyRewardsByPosition(uint256 _position) public view returns(uint256) {
        return ambassadorMonthlyRewardsByPosition[_position];
    }
    // set the ambassadorMonthlyRewardsByPosition at position position to percent
    function setAmbassadorMonthlyRewardsByPosition(uint256 _position, uint256 _percent) public onlyOwner {
        ambassadorMonthlyRewardsByPosition[_position] = _percent;
    }

    /*// returns totalDailyClaimHitZeroBlock
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
     * @param _claimAddress the address to look up
     * @return _claimableBalance the claimable balance attaached to teh address _claimAddress
     */
    function getClaimableBalance(address _claimAddress) public view returns(uint256 _claimableBalance) {
        return userClaimedBalances[_claimAddress].claimableBalance;
    }

    /**
     * @dev sets the claimableBalance at address claimAddress to claimableBalance
     * @param _claimAddress the address to set
     * @param _claimableBalance the balance to set
     *
     */
    function setClaimableBalance(address _claimAddress, uint256 _claimableBalance) public onlyOwner {
        userClaimedBalances[_claimAddress].claimableBalance = _claimableBalance;
    }

    /** @dev create a new claimer address _claimerAddress with claimer balance set to _claimerBalance
     * @param _claimAddress (the address who will be claiming the token)
     * @param _claimableBalance (the total amount that the address can claim)
     *
     * TODO: Figure out a way to make the address claimableBalance additive not fixed
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

    /**
     * @dev returns the candidateList at index _index
     * @return _name, _surname, _metadata, _votes, _candidateAddress of the candidate
     */
    function getCandidateList(uint256 _index) public view returns(string _name, string _surname, string _metadata, uint256 _votes, address _candidateAddress) {
        require(candidateListAddresses[_index] != address(0));

        CandidateStruct memory c = candidateList[candidateListAddresses[_index]];
        return (c.name, c.surname, c.metadata, c.votes, c.candidateAddress);
    }

    /**
     * @dev returns the ambssadorList at index _index
     * @return _ambassadorAddressm,_blockStarted, _totalVotes, _rank of the ambsasador
     */
    function getAmbassadorList(uint256 _index) public view returns(address _ambassadorAddress, uint256 _blockStarted, uint256 _totalVotes, uint256 _rank) {
        AmbassadorStuct memory a = ambassadorList[_index];
        return (a.ambassadorAddress, a.blockStarted, a.totalVotes, a.rank);
    }

    /**
     * @dev claim XBO tokens daily
     *
     * checks whether the clalimer is the Origin foundation address or not
     * checks the total claimed amount for the contract
     * checks the total claimed amount for the address
     * based on those, we mint the required number of tokens for the address.
     *
     * @return _success true/false if successful
     */
    function claim() public canClaim returns (bool _success) {
        // Reset daily user block limit on a per user basis
        if (userClaimedBalances[msg.sender].blockNumber.add(blocksInADay) >= block.number) {
            userClaimedBalances[msg.sender].blockNumber = block.number;
            if(msg.sender == owner) {
                userClaimedBalances[msg.sender].remainingDailyBalance = maxFoundationIndividualDailyClaim;
            } else {
                userClaimedBalances[msg.sender].remainingDailyBalance = maxIndividualDailyClaim;
            }
        }

        // Reset total daily block limit for all users if true
        if(msg.sender == owner) {
            if (totalFoundationDailyClaimHitZeroBlock.add(blocksInADay) >= block.number) {
                totalFoundationDailyClaimHitZeroBlock = block.number;
                totalFoundationDailyClaim = forkedCoinSupply.div(730);
            }
        } else {
            if (totalDailyClaimHitZeroBlock.add(blocksInADay) >= block.number) {
                //TODO: this might skip a couple of blocks. Would it not be better to do something along the lines of totalDailyClaimHitZeroBlock = totalDailyClaimHitZeroBlock.add(blocksInADay);
                //      ie. always increment it by 1 day? What happens if nobody claims in a day then?
                //          maybe uint256 days = (block.numebr-totalDailyClaimHitZeroBlock).div(blocksInADay);
                //          if (days >= 1) { totalDailyClaimHitZeroBlock.add(blocksInADay.mul(days)); totalDailyClaim = forkedCoinSupply.div(730); }
                //      same logic applies to the check above for the foundation
                totalDailyClaimHitZeroBlock = block.number;
                totalDailyClaim = forkedCoinSupply.div(730);
            }
        }

        //Base potential claim amount calculated as claimable balance (value left over from total claimable balance) − totalClaimed so far
        uint256 claimableAmount = userClaimedBalances[msg.sender].claimableBalance.sub(userClaimedBalances[msg.sender].totalClaimedBalance);

        // First limiter checks user daily remaining balance
        if (claimableAmount > userClaimedBalances[msg.sender].remainingDailyBalance) {
            claimableAmount = userClaimedBalances[msg.sender].remainingDailyBalance;
        }

        // Second limiter checks total daily limit
        if(msg.sender == owner) {
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
            if(msg.sender == owner) {
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

    /**
     * @dev calculates the staking reward for the address based on staked amount relative to total staked amount and staked period
     * @return _stakeReward the reward for staking
     */
    function calculateReward() internal view returns(uint256 _stakeReward) {
        if(userStakeHistory[msg.sender].length == 0 || stakeHistoryLength == 0) {
            return 0;
        }

        uint256 userStakeI = userStakeHistory[msg.sender].length.sub(1);
        uint256 stakeReward = 0;

        if(userStakeI >= 0) {
            uint256 totalStakeI = stakeHistoryLength.sub(1);
            uint256 calculationCurrentBlock = block.number;
            uint256 calculationPreviousBlock = stakeHistory[totalStakeI].currentTotalStakeBlock;
            uint256 calculationPreviousBlockStake = stakeHistory[totalStakeI].currentTotalStake;
            uint256 calculationUserStakeBlock = userStakeHistory[msg.sender][userStakeI].userStakeBlock;

            uint256 stakeRatio = 0;
            uint256 blocksStakedFor = 0;
            uint256 reward = 0;


            //calculate stake from current block to last stake entry
            while (totalStakeI > 0 && calculationPreviousBlock >= calculationUserStakeBlock) {
                if(calculationPreviousBlockStake > 0 && calculationPreviousBlock > 0) {
                    //do the stake reward calculation
                    stakeRatio = userStakeHistory[msg.sender][userStakeI].userStake.div(calculationPreviousBlockStake);
                    blocksStakedFor = calculationCurrentBlock.sub(calculationPreviousBlock);
                    reward = stakeRatio.mul(dailyStakingRewards).mul(blocksStakedFor).div(blocksInADay);
                    stakeReward = stakeReward.add(reward);
                }

                calculationCurrentBlock = stakeHistory[totalStakeI].currentTotalStakeBlock;

                totalStakeI = totalStakeI.sub(1);

                calculationPreviousBlock = stakeHistory[totalStakeI].currentTotalStakeBlock;
                calculationPreviousBlockStake = stakeHistory[totalStakeI].currentTotalStake;
            }
        }

        return stakeReward;
    }

    /**
     * @dev stakes a portion of the tokens for an address
     * @param _amount the amount to be staked
     *
     * validates if the address can stake the amount (balance >= stake)
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

        mint(msg.sender, calculateReward());

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
        userStakeHistory[msg.sender].push(UserStakeHistoryStruct({
            totalStakeIndex: currentUserStakesStruct.stakeIndex,
            userStake: currentUserStakesStruct.stake,
            userStakeBlock: block.number
        }));

        stakeHistory[stakeHistoryLength] = CurrentTotalStakesStruct({
            currentTotalStakeIndex: currentTotalStakeIndex,
            currentTotalStake: stakedSupply_,
            currentTotalStakeBlock: block.number
        });
        stakeHistoryLength = stakeHistoryLength.add(1);
    }

    /**
     * @dev stops staking a portion of the tokens for an address
     * @param _amount the amount to be unstaked
     *
     * validates if the address can stop staking the amount (stake >= balance)
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

        mint(msg.sender, calculateReward());

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
        userStakeHistory[msg.sender].push(UserStakeHistoryStruct({
            totalStakeIndex: currentUserStakesStruct.stakeIndex,
            userStake: currentUserStakesStruct.stake,
            userStakeBlock: block.number
        }));

        stakeHistory[stakeHistoryLength] = CurrentTotalStakesStruct({
            currentTotalStakeIndex: currentTotalStakeIndex,
            currentTotalStake: stakedSupply_,
            currentTotalStakeBlock: block.number
        });
        stakeHistoryLength = stakeHistoryLength.add(1);
    }

    /**
     * @dev add a candidate to the candidateList
     * @param _address the address of the candidate
     * @param _name the name of the candidate
     * @param _surname the surname of the candidate
     * @param _metadata the metadata of the candidate (youtuber, influencer, journalist, nodeRunner etc.)
     *
     */
    function addToCandidateList(address _address, string _name, string _surname, string _metadata) public onlyOwner {
        candidateList[_address] = CandidateStruct({
            name: _name,
            surname: _surname,
            metadata: _metadata,
            votes: 0,
            candidateAddress: _address
        });
        candidateListAddresses[candidateListAddressesLength] = _address;
        candidateListAddressesLength = candidateListAddressesLength.add(1);
    }

    /**
    * @dev remvoes all candidates from the candidateList
    *
    */
    function clearCandidateList() private {
        for(uint256 i = 0; i < candidateListAddressesLength; i++) {
            delete candidateList[candidateListAddresses[i]];
            delete candidateListAddresses[i];
        }
        candidateListAddressesLength = 0;
    }

    /**
    * @dev starts the voting process
    *
    * Rests all existing votes in the system so that we can start a new round
    * Clears all the existing candidates from teh candidateList so that a new one can be generated
    *
    */
    function startVote() public onlyOwner isClosed {
        resetVote();
        clearCandidateList();
        voteOpen = true;
        //voteOpenBlock = block.number;
    }

    /**
    * @dev ends the voting process
    *
    * rewards all the ambassadors for the previous month based on their position in the list.
    * sorts the candidates in order of votes received then creates the new ambsasador list.
    *
    */
    function endVote() public onlyOwner isOpen {
        voteOpen = false;

        // Step 1: Reward Ambassadors for past month, always 1 month trailing
        rewardAmbassadors();

        // standard quicksort, but on votes not on array index, array index for now for simplicity
        sortCandidates();

        //need to reset current ambassadors first

        //populate 1:maxAmbassadors
        uint256 limit = (maxAmbassadors < candidateListAddressesLength) ? maxAmbassadors : candidateListAddressesLength;
        for(uint256 i = 0; i < limit; i++) {
            ambassadorList[i] = AmbassadorStuct({
                ambassadorAddress: candidateListAddresses[i],
                blockStarted: block.number,
                totalVotes: candidateList[candidateListAddresses[i]].votes,
                rank: i.add(1)
            });
            ambassadorListLength = ambassadorListLength.add(1);
        }
    }

    /**
    * @dev casts a vote for a candidate from the candidateList. Vote weighting is based on staked amount
    *
    */
    function castVote(address _address) public canVote {
        voters[msg.sender].voted = true;
        voters[msg.sender].votes = stakeOf(msg.sender);
        candidateList[_address].votes = candidateList[_address].votes.add(stakeOf(msg.sender));
        votersAddresses[votersAddressesLength] = msg.sender;
        votersAddressesLength = votersAddressesLength.add(1);

        totalVotes = totalVotes.add(stakeOf(msg.sender));
    }

    /**
     * @dev resets the votes for the candidates. Allowing addresses to vote in the next round of voting.
     *
     */
    function resetVote() private {
        uint256 ratio = 0;

        for(uint256 i = 0; i < votersAddressesLength; i++) {
            //blocks = block.number − voters[i].block // How many total blocks
            //uint256 blocks = block.number.sub(voters[i].block);
            //ratio = votes / totalVotes // participation of total votes
            if(totalVotes != 0) {
                ratio = voters[votersAddresses[i]].votes.div(totalVotes);
                //reward = ratio ∗ blockVoterDistribution
                mint(voters[votersAddresses[i]].voterAddress, ratio.mul(dailyVoterDistribution.div(blocksInADay)));
            }

            voters[votersAddresses[i]].voted = false;
            voters[votersAddresses[i]].votes = 0;

            //do we want to change the index of all of them?
            delete votersAddresses[i];
        }

        votersAddressesLength = 0;
        totalVotes = 0;
    }

    /**
     * @dev Sorts the candidates in the order of their votes reveived. Most votes first.
     *
     */
    function sortCandidates() internal{
        address tmp;
        for(uint256 i = 0; i < candidateListAddressesLength; i++) {
            for(uint256 j = 0; j < candidateListAddressesLength.sub(i); j++) {
                if(candidateList[candidateListAddresses[j.add(1)]].votes>candidateList[candidateListAddresses[j]].votes){
                    tmp = candidateListAddresses[j.add(1)];
                    candidateListAddresses[j.add(1)] = candidateListAddresses[j];
                    candidateListAddresses[j] = tmp;
                }
            }
        }
    }

    function rewardAmbassadors() internal {
        uint256 limit = (maxAmbassadors < ambassadorListLength) ? maxAmbassadors : ambassadorListLength;
        for(uint256 i = 0; i < limit; i++) {
            uint256 reward = dailyAmbassadorRewards.mul(365).div(12).mul(ambassadorMonthlyRewardsByPosition[i]).div(100);
            mint(ambassadorList[i].ambassadorAddress, reward);
        }
    }
}
