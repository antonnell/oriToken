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

    event Notify(address indexed _sender, uint256 _value, bytes _extraData);

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public returns (bool) {
        super.transfer(_to, _value);

        bytes storage data;
        notify(msg.sender, _value, data);
        return true;
    }

    function notify(address _sender, uint256 _value, bytes _extraData) public returns (bool) {
        emit Notify(_sender, _value, _extraData);
        return true;
    }
}
