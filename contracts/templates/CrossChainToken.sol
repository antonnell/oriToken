pragma solidity ^0.4.21;

import "./BasicToken.sol";

/**
 * @title CrossChain Token
 * @dev Token that can be decreased on this chain to be incremented on another chain
 * @dev The CrossChain Transfer event will be used as input for the other chain
 */
contract CrossChainToken is BasicToken {

    event CrossChainTransfer(address indexed burner, uint256 value);

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function crossChainTransfer(uint256 _value) public {
        _crossChainTransfer(msg.sender, _value);
    }

    function _crossChainTransfer(address _from, uint256 _value) internal {
        require(_value <= balances[_from]);
        balances[_from] = balances[_from].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
        emit CrossChainTransfer(_from, _value);
        emit Transfer(_from, address(0), _value);
    }
}
