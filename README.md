# Origin Token

The basic Origin ERC20 token.

```
  Ownable
  Pausable
  Burnable
  Mintable
  Stakeable
  CrossChainable
```

## Origin Proof of Ambassador Logic:

The contract starts off with nothing really happening inside of it. At any point, the owner of the contract can set the foundation's address. Should be done in the beginning of the lifecycle so that the foundation can claim their tokens daily.
The owner can set the foundation address (  setFoundationAddress() )
The owner can get the foundation's address (  getFoundationAddress() )

** I will be adding functionality to set the bitcoinPeggedPrice, XBOPeggedPrice, Ambasador/Staker/voting reward percentages, maxAmbassadors etc for the owner/foundation to manipulate. But for now, nothing.


But nobody has any balance yet. This is where Feature 1: Claim comes into it. 
The owner(or foundation) will set the claimable balances of everyone that has registered to claim tokens. ( createNewClaimer() )
Users can query their total claimable balance (  getClaimableBalance() )
The owner(or foundation) can update that balance if for some reason the balance changes (they add their litecoin/dash/eth etc addresses to the system) (  setClaimableBalance() )
Users can claim their tokens daily. This is limitted to X number of tokens per day (see spec for calculation) ( claim() )

Once the users have a balance, they will start staking their tokens so that they can vote on ambassadors and get rewards for staking and voting.
Users can start staking their tokens ( startStaking() )
Users can stop staking their tokens ( stopStaking() )
Users can see their staked balance ( stakeOf() )

Now that they have staked their tokens, the voting process can commence. The discussions we had with JP was that there would be monthly voting rounds for new ambassadors.
The owner (or foundation) will start the voting round. This clears the candidate list. This also resets all the votes of the previous month. ( startVote() )
The owner will then add candidates to the candidate list via: (  addToCandidateList() )
Users will be able to view the candidate list using (  getCandidateList() )
Users will then vote for the candidate that they like ( castVote() )
The owner (or foundation) will then end the voting round after a specific amount of time. This will reward all the previous month's ambassadors. This  will also tally all the votes and appoint the new ambassador list. ( endVote() )
The cycle can now repeat.

Ambassadors have now been elected.
User can view ambassadors ( getAmbassadorList() )