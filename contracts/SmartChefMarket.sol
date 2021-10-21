//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SmartChefMarket is Ownable {
    using SafeERC20 for IERC20;

    uint public totalTokensPlaced;
    uint public lastRewardBlock;
    address[] public listRewardTokens;
    address market;

    struct RewardToken {
        uint rewardPerBlock;
        uint startBlock;
        uint accTokenPerShare; // Accumulated Tokens per share, times 1e12.
        uint rewardsForWithdrawal;
        bool enabled; // true - enable; false - disable
    }

    mapping (address => uint) public userNFTPlaced; //How many tokens placed in market by user
    mapping (address => mapping(address => uint)) public rewardDebt; //user => (rewardToken => rewardDebt);
    mapping (address => RewardToken) public rewardTokens;

    event AddNewTokenReward(address token);
    event DisableTokenReward(address token);
    event ChangeTokenReward(address indexed token, uint rewardPerBlock);
    //    event StakeTokens(address indexed user, uint amountRB, uint[] tokensId);
    //    event UnstakeToken(address indexed user, uint amountRB, uint[] tokensId);
    event EmergencyWithdraw(address indexed user, uint tokenCount);

    modifier onlyMarket(){
        require(msg.sender == market, "Only market");
        _;
    }

    function isTokenInList(address _token) internal view returns(bool){
        address[] memory _listRewardTokens = listRewardTokens;
        bool thereIs = false;
        for(uint i = 0; i < _listRewardTokens.length; i++){
            if(_listRewardTokens[i] == _token){
                thereIs = true;
                break;
            }
        }
        return thereIs;
    }


    function getListRewardTokens() public view returns(address[] memory){
        address[] memory list = new address[](listRewardTokens.length);
        list = listRewardTokens;
        return list;
    }

    function addNewTokenReward(address _newToken, uint _startBlock, uint _rewardPerBlock) public onlyOwner {
        require(_newToken != address(0), "Address shouldn't be 0");
        require(isTokenInList(_newToken) == false, "Token is already in the list");
        listRewardTokens.push(_newToken);
        if(_startBlock == 0){
            rewardTokens[_newToken].startBlock = block.number + 1;
        } else {
            rewardTokens[_newToken].startBlock = _startBlock;
        }
        rewardTokens[_newToken].rewardPerBlock = _rewardPerBlock;
        if(IERC20(_newToken).balanceOf(address(this)) > rewardTokens[_newToken].rewardsForWithdrawal){
            rewardTokens[_newToken].enabled = true;
        } else {
            rewardTokens[_newToken].enabled = false;
        }
        emit AddNewTokenReward(_newToken);
    }

    function disableTokenReward(address _token) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        rewardTokens[_token].enabled = false;
        emit DisableTokenReward(_token);
    }

    function enableTokenReward(address _token, uint _startBlock, uint _rewardPerBlock) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(_startBlock >= block.number, "Start block Must be later than current");
        if(IERC20(_token).balanceOf(address(this)) > rewardTokens[_token].rewardsForWithdrawal){
            rewardTokens[_token].enabled = true;
            rewardTokens[_token].startBlock = _startBlock;
            rewardTokens[_token].rewardPerBlock = _rewardPerBlock;
            emit ChangeTokenReward(_token, _rewardPerBlock);
        } else {
            revert("Not enough balance of token");
        }
        updatePool();
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint _from, uint _to) public pure returns (uint) {
        if(_to > _from){
            return _to - _from;
        } else {
            return 0;
        }
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address _user) external view returns (address[] memory, uint[] memory) {
        uint nftPlaced = userNFTPlaced[_user];
        uint[] memory rewards = new uint[](listRewardTokens.length);
        if(nftPlaced == 0){
            return (listRewardTokens, rewards);
        }
        uint _totalTokensPlaced = totalTokensPlaced;
        uint _multiplier = getMultiplier(lastRewardBlock, block.number);
        uint _accTokenPerShare = 0;
        for(uint i = 0; i < listRewardTokens.length; i++){
            address curToken = listRewardTokens[i];
            RewardToken memory curRewardToken = rewardTokens[curToken];
            if (_multiplier != 0 && _totalTokensPlaced != 0) {
                _accTokenPerShare = curRewardToken.accTokenPerShare +
                (_multiplier * curRewardToken.rewardPerBlock * 1e12 / _totalTokensPlaced);
            } else {
                _accTokenPerShare = curRewardToken.accTokenPerShare;
            }
            rewards[i] = (nftPlaced * _accTokenPerShare / 1e12) - rewardDebt[_user][curToken];
        }
        return (listRewardTokens, rewards);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        uint multiplier = getMultiplier(lastRewardBlock, block.number);
        uint _totalTokenPlaced = totalTokensPlaced; //Gas safe

        if(multiplier == 0){
            return;
        }
        lastRewardBlock = block.number;
        if(_totalTokenPlaced == 0){
            return;
        }
        for(uint i = 0; i < listRewardTokens.length; i++){
            address curToken = listRewardTokens[i];
            RewardToken memory curRewardToken = rewardTokens[curToken];
            if(curRewardToken.enabled == false || curRewardToken.startBlock >= block.number){
                continue;
            } else {
                uint curMultiplier;
                if(getMultiplier(curRewardToken.startBlock, block.number) < multiplier){
                    curMultiplier = getMultiplier(curRewardToken.startBlock, block.number);
                } else {
                    curMultiplier = multiplier;
                }
                uint tokenReward = curRewardToken.rewardPerBlock * curMultiplier;
                rewardTokens[curToken].rewardsForWithdrawal += tokenReward;
                rewardTokens[curToken].accTokenPerShare += (tokenReward * 1e12) / _totalTokenPlaced;
            }
        }
    }

    function withdrawReward() public {
        _withdrawReward(msg.sender);
    }

    function _updateRewardDebt(address _user) internal {
        for(uint i = 0; i < listRewardTokens.length; i++){
            rewardDebt[_user][listRewardTokens[i]] = userNFTPlaced[_user] * rewardTokens[listRewardTokens[i]].accTokenPerShare / 1e12;
        }
    }

    function _withdrawReward(address _user) internal {
        updatePool();
        uint nftPlaced = userNFTPlaced[_user];
        address[] memory _listRewardTokens = listRewardTokens;
        if(nftPlaced == 0){
            return;
        }
        for(uint i = 0; i < _listRewardTokens.length; i++){
            RewardToken storage curRewardToken = rewardTokens[_listRewardTokens[i]];
            uint pending = nftPlaced * curRewardToken.accTokenPerShare / 1e12 - rewardDebt[_user][_listRewardTokens[i]];
            if(pending > 0){
                curRewardToken.rewardsForWithdrawal -= pending;
                rewardDebt[_user][_listRewardTokens[i]] = nftPlaced * curRewardToken.accTokenPerShare / 1e12;
                IERC20(_listRewardTokens[i]).safeTransfer(address(_user), pending);
            }
        }
    }

    function updateStakedTokens(address _user, uint amount) public onlyMarket {
        _withdrawReward(_user);
        totalTokensPlaced -= userNFTPlaced[_user];
        userNFTPlaced[_user] = amount;
        totalTokensPlaced += amount;

        _updateRewardDebt(_user);
    }

    // Withdraw reward token. EMERGENCY ONLY.
    function emergencyRewardTokenWithdraw(address _token, uint256 _amount) public onlyOwner {
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Not enough balance");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function setMarket(address _market) public onlyOwner {
        market = _market;
    }
}