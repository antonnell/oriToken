pragma solidity ^0.4.21;

import "./BasicToken.sol";

/**
 * @title StakedToken Token
 * @dev Token that can staked and have the stake registered
 */

 /* Challenges, get a list of all accounts and their associated balances */

contract StakedToken is BasicToken {

    event Stake(address indexed staker, uint256 value);
    event StopStaking(address indexed staker, uint256 value);

    mapping(address => uint256) public stakes;
    uint256 public stakedSupply_;

    /**
    * @dev staked number of tokens in existence
    */
    function totalStake() public view returns (uint256) {
        return stakedSupply_;
    }

    /**
    * @dev Gets the staked balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function stakeOf(address _owner) public view returns (uint256) {
        return stakes[_owner];
    }

    /**
     * @dev Stake a specific amount of tokens.
     * @param _value The amount of token to be staked.
     */
    function stake(uint256 _value) public {
        _stake(msg.sender, _value);
    }

    /**
     * @dev Stop staking a specific amount of tokens.
     * @param _value The amount of token to be released.
     */
    function stopStaking(uint256 _value) public {
        _stopStaking(msg.sender, _value);
    }

    function _stake(address _from, uint256 _value) internal {
        require(_value <= balances[_from]);
        balances[_from] = balances[_from].sub(_value);
        stakes[_from] = stakes[_from].add(_value);
        stakedSupply_ = stakedSupply_.add(_value);
        emit Stake(_from, _value);
    }

    function _stopStaking(address _from, uint256 _value) internal {
        require(_value <= stakes[_from]);
        stakes[_from] = stakes[_from].sub(_value);
        balances[_from] = balances[_from].add(_value);
        stakedSupply_ = stakedSupply_.sub(_value);
        emit StopStaking(_from, _value);
    }
}
