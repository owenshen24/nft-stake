pragma solidity ^0.6.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTStaker is ERC721Burnable, Ownable {

  using SafeERC20 for IERC20;
  using Counters for Counters.Counter;

  struct Stake {
    uint256 amount;
    uint256 startBlock;
    uint256 rewardId;
    bool hasMinted;
  }

  struct Reward {
    address minter;
    uint256 amount;
    uint256 startBlock;
    uint256 endBlock;
    bool isStaked;
  }

  Counters.Counter private _rewardIds;
  IERC20 public token;
  address _tokenAddress;
  uint256 public totalStaked;
  string _contractURI;

  mapping(address => Stake) public stakeRecords;
  mapping(uint256 => Reward) public rewardRecords;

  constructor(address tokenAddress, string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) public {
    token = IERC20(tokenAddress);
    _tokenAddress = tokenAddress;
    _setBaseURI(baseURI);
  }

  function addStake(uint256 numTokens) public returns(bool){
    require(token.balanceOf(msg.sender) >= numTokens, "over stake");
    require(stakeRecords[msg.sender].amount == 0, "already staking");

    // Update the mapping used to keep track of nfts
    _rewardIds.increment();
    uint256 currId = _rewardIds.current();
    stakeRecords[msg.sender] = Stake(
      numTokens,
      block.number,
      currId,
      false
    );
    // Update the totalStaked count
    totalStaked = totalStaked + numTokens;

    // Transfer tokens to contract
    token.safeTransferFrom(msg.sender, address(this), numTokens);
    return true;
  }

  function removeStake() public returns(bool) {
    uint256 numTokens = stakeRecords[msg.sender].amount;
    uint256 currId = stakeRecords[msg.sender].rewardId;

    require(numTokens > 0, "not staking");

    // Reduce the totalStaked count
    totalStaked = totalStaked - numTokens;

    // Remove the mapping
    delete stakeRecords[msg.sender];

    // Update the NFT's records
    rewardRecords[currId].endBlock = block.number;
    rewardRecords[currId].isStaked = false;

    // Transfer the staked tokens back
    token.safeTransfer(msg.sender, numTokens);
    return true;
  }

  function mintReward() public returns (uint256) {
    // require stake to be valid before minting
    require(stakeRecords[msg.sender].amount > 0, "must be staking");
    require(stakeRecords[msg.sender].hasMinted == false, "already minted");

    // set hasMinted to true to prevent multiple mintings per stake
    stakeRecords[msg.sender].hasMinted = true;

    // Set NFT data
    uint256 newRewardId = stakeRecords[msg.sender].rewardId;
    rewardRecords[newRewardId] = Reward(
      msg.sender,
      stakeRecords[msg.sender].amount,
      stakeRecords[msg.sender].startBlock,
      0,
      true
    );
    _safeMint(msg.sender, newRewardId);
    return newRewardId;
  }

  function rescue(address otherTokenAddress, address to, uint256 numTokens) public onlyOwner {
    require(otherTokenAddress != _tokenAddress, "rescuing staked token");
    IERC20 otherToken = IERC20(otherTokenAddress);
    otherToken.safeTransfer(to, numTokens);
  }

  function setBaseURI(string memory uri) public onlyOwner {
    _setBaseURI(uri);
  }

  function setContractURI(string memory uri) public onlyOwner {
    _contractURI = uri;
  }

  function contractURI() public view returns (string memory) {
    return _contractURI;
  }
}