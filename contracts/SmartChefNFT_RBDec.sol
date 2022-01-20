//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
//BNF-02
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

interface IBiswapNFT {
    function accrueRB(address user, uint amount) external;
    function tokenFreeze(uint tokenId) external;
    function tokenUnfreeze(uint tokenId) external;
    function getRB(uint tokenId) external view returns(uint);
    function getInfoForStaking(uint tokenId) external view returns(address tokenOwner, bool stakeFreeze, uint robiBoost);
    function decreaseRB(uint[] calldata tokensId, uint decreasePercent, uint minDecreaseLevel, address user) external returns(uint decreaseAmount);
    function decreaseRBView(uint[] calldata tokensId, uint decreasePercent, uint minDecreaseLevel) external view returns(uint decreaseAmount);
    function getLevel(uint tokenId) external view returns (uint);
}

contract SmartChefNFTRBDec is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public totalRBSupply;
    uint public lastRewardBlock;
    address[] public listRewardTokens;
    IBiswapNFT public nftToken;

    uint minDecreaseLevel;
    uint decreasePerPeriod; //base 1e12

    // Info of each user
    struct UserInfo {
        uint[] stakedTokensId;
        uint stakedRbAmount;
        uint lastActionDay;
    }

    struct RewardToken {
        uint rewardPerBlock;
        uint startBlock;
        uint accTokenPerShare; // Accumulated Tokens per share, times 1e12.
        uint rewardsForWithdrawal;
        bool enabled; // true - enable; false - disable
    }

    mapping (address => UserInfo) public userInfo;
    mapping (address => mapping(address => uint)) public rewardDebt; //user => (rewardToken => rewardDebt);
    mapping (address => RewardToken) public rewardTokens;
    mapping(uint => uint[]) public compoundInterest;

    event AddNewTokenReward(address token);
    event DisableTokenReward(address token);
    event ChangeTokenReward(address indexed token, uint rewardPerBlock);
    event StakeTokens(address indexed user, uint amountRB, uint[] tokensId);
    event UnstakeToken(address indexed user, uint amountRB, uint[] tokensId);
    event EmergencyWithdraw(address indexed user, uint tokenCount);

    constructor(IBiswapNFT _nftToken) {
        nftToken = _nftToken;
        minDecreaseLevel = 1;
        decreasePerPeriod = 4000000000;
    }

    function isTokenInList(address _token) internal view returns(bool){
        address[] memory _listRewardTokens = listRewardTokens;
        for(uint i = 0; i < _listRewardTokens.length; i++){
            if(_listRewardTokens[i] == _token) return true;
        }
        return false;
    }

    function getUserInfo(address _user) public view returns(uint[] memory _stakedTokensId, uint _stakedRbAmount, uint _lastActionBlockNumber) {
        _stakedTokensId = new uint[](userInfo[_user].stakedTokensId.length);
        _stakedTokensId = userInfo[_user].stakedTokensId;
        _stakedRbAmount = userInfo[_user].stakedRbAmount;
        _lastActionBlockNumber = userInfo[_user].lastActionDay;
    }

    function getUserStakedTokens(address _user) public view returns(uint[] memory){
        return userInfo[_user].stakedTokensId;
    }

    function getUserStakedRbAmount(address _user) public view returns(uint){
        return userInfo[_user].stakedRbAmount;
    }

    function getListRewardTokens() public view returns(address[] memory){
        return listRewardTokens;
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
        rewardTokens[_newToken].enabled = true;

        emit AddNewTokenReward(_newToken);
    }

    function setDecreaseRBParams(uint _minDecreaseLevel, uint _decreasePerPeriod) public onlyOwner {
        require(_decreasePerPeriod <= 1e12, "decrease per period out of bound");
        minDecreaseLevel = _minDecreaseLevel;
        decreasePerPeriod = _decreasePerPeriod;
    }

    function disableTokenReward(address _token) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        updatePool();
        rewardTokens[_token].enabled = false;
        emit DisableTokenReward(_token);
    }

    function enableTokenReward(address _token, uint _startBlock, uint _rewardPerBlock) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(!rewardTokens[_token].enabled, "Reward token is enabled");
        if(_startBlock == 0){
            _startBlock = block.number + 1;
        }
        require(_startBlock >= block.number, "Start block Must be later than current");
        rewardTokens[_token].enabled = true;
        rewardTokens[_token].startBlock = _startBlock;
        rewardTokens[_token].rewardPerBlock = _rewardPerBlock;
        emit ChangeTokenReward(_token, _rewardPerBlock);

        updatePool();
    }

    function updateTokenReward(address _token, uint _startBlock, uint _rewardPerBlock) public onlyOwner { //TODO test me!
        require(isTokenInList(_token), "Token not in the list");
        require(!rewardTokens[_token].enabled, "Reward token is enabled");
        if(_startBlock == 0){
            _startBlock = block.number + 1;
        }
        require(_startBlock >= block.number, "Start block Must be later than current");
        updatePool();
        rewardTokens[_token].startBlock = _startBlock;
        rewardTokens[_token].rewardPerBlock = _rewardPerBlock;
        emit ChangeTokenReward(_token, _rewardPerBlock);
    }

    function calcCompoundInterest() external onlyOwner {
        _calcCompoundInterest();
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
    function pendingReward(address _user) external view returns (address[] memory, uint[] memory, uint) { //TODO test me!
        UserInfo memory user = userInfo[_user];
        uint[] memory rewards = new uint[](listRewardTokens.length);
        if(user.stakedRbAmount == 0){
            return (listRewardTokens, rewards, 0);
        }
        uint _totalRBSupply = totalRBSupply;
        uint _multiplier = getMultiplier(lastRewardBlock, block.number);
        uint _accTokenPerShare = 0;
        for(uint i = 0; i < listRewardTokens.length; i++){
            address curToken = listRewardTokens[i];
            RewardToken memory curRewardToken = rewardTokens[curToken];
            if (_multiplier != 0 && _totalRBSupply != 0 && curRewardToken.enabled == true) {
                uint curMultiplier;
                if(getMultiplier(curRewardToken.startBlock, block.number) < _multiplier){
                    curMultiplier = getMultiplier(curRewardToken.startBlock, block.number);
                } else {
                    curMultiplier = _multiplier;
                }
                _accTokenPerShare = curRewardToken.accTokenPerShare +
                (curMultiplier * curRewardToken.rewardPerBlock * 1e12 / _totalRBSupply);
            } else {
                _accTokenPerShare = curRewardToken.accTokenPerShare;
            }
            rewards[i] = (user.stakedRbAmount * _accTokenPerShare / 1e12) - rewardDebt[_user][curToken];
        }
        uint decreaseAmount =  pendingDecreaseRB(_user);
        return (listRewardTokens, rewards, decreaseAmount);
    }

    function pendingDecreaseRB(address _user) public view returns(uint decreaseAmount){
        UserInfo memory user = userInfo[_user];
        uint daysPassed = block.timestamp/1 days - user.lastActionDay;
        uint decreasePercent = getDecreasePercent(daysPassed);
        decreaseAmount = nftToken.decreaseRBView(user.stakedTokensId, decreasePercent, minDecreaseLevel);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        uint multiplier = getMultiplier(lastRewardBlock, block.number);
        uint _totalRBSupply = totalRBSupply; //Gas safe

        if(multiplier == 0){
            return;
        }
        lastRewardBlock = block.number;
        if(_totalRBSupply == 0){
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
                rewardTokens[curToken].accTokenPerShare += (tokenReward * 1e12) / _totalRBSupply;
            }
        }
    }

    function withdrawReward() public {
        _withdrawReward();
    }

    function _updateRewardDebt(address _user) internal {
        for(uint i = 0; i < listRewardTokens.length; i++){
            rewardDebt[_user][listRewardTokens[i]] = userInfo[_user].stakedRbAmount * rewardTokens[listRewardTokens[i]].accTokenPerShare / 1e12;
        }
    }

    function decreaseRB(address _user) internal {
        UserInfo storage user = userInfo[_user];
        if(user.lastActionDay == 0) user.lastActionDay = block.timestamp/1 days;
        uint daysPassed = block.timestamp/1 days - user.lastActionDay;
        if(user.stakedRbAmount == 0 || daysPassed == 0) return;
        uint decreasePercent = getDecreasePercent(daysPassed);
        uint decreaseAmount = nftToken.decreaseRB(user.stakedTokensId, decreasePercent, minDecreaseLevel, _user);
        user.stakedRbAmount -= decreaseAmount;
        totalRBSupply -= decreaseAmount;
        user.lastActionDay = block.timestamp/1 days;
    }

    function getDecreasePercent(uint period) internal view returns(uint res){
        require(period < 10000, "Period to high");
        res = 1e12;
        uint i = 3;
        while(i >=0){
            if(period >= 10**i){
                uint numb = period / 10**i;
                res = res * compoundInterest[i][numb]/1e12;
                period -= numb * 10**i;
            }
            if(i == 0) break;
            i--;
        }
    }

    function _calcCompoundInterest() internal {
        uint decPeriod = 0;
        uint mult;
        mult = (1e12 - decreasePerPeriod);
        for(uint k = 0; k < 4; k++){
            decPeriod = mult;
            compoundInterest[k].push(1e12);
            compoundInterest[k].push(decPeriod);
            for(uint i = 0; i < 8; i++){
                decPeriod = decPeriod * mult / 1e12;
                compoundInterest[k].push(decPeriod);
            }
            mult = compoundInterest[k][1] * compoundInterest[k][9]/1e12;
        }
    }


    //SCN-01, SFR-02
    function _withdrawReward() internal {
        updatePool();
        UserInfo memory user = userInfo[msg.sender];
        address[] memory _listRewardTokens = listRewardTokens;
        if(user.stakedRbAmount == 0){
            return;
        }
        for(uint i = 0; i < _listRewardTokens.length; i++){
            RewardToken storage curRewardToken = rewardTokens[_listRewardTokens[i]];
            uint pending = user.stakedRbAmount * curRewardToken.accTokenPerShare / 1e12 - rewardDebt[msg.sender][_listRewardTokens[i]];
            if(pending > 0){
                curRewardToken.rewardsForWithdrawal -= pending;
                rewardDebt[msg.sender][_listRewardTokens[i]] = user.stakedRbAmount * curRewardToken.accTokenPerShare / 1e12;
                IERC20(_listRewardTokens[i]).safeTransfer(address(msg.sender), pending);
            }
        }
        decreaseRB(msg.sender);
    }

    function removeTokenIdFromUserInfo(uint index, address user) internal {
        uint[] storage tokensId = userInfo[user].stakedTokensId;
        tokensId[index] = tokensId[tokensId.length - 1];
        tokensId.pop();
    }

    // Stake _NFT tokens to SmartChefNFT
    //BNF-02, SFR-02
    function stake(uint[] calldata tokensId) public nonReentrant {
        _withdrawReward();
        uint depositedRobiBoost = 0;
        for(uint i = 0; i < tokensId.length; i++){
            (address tokenOwner, bool stakeFreeze, uint robiBoost) = nftToken.getInfoForStaking(tokensId[i]);
            require(tokenOwner == msg.sender, "Not token owner");
            require(stakeFreeze == false, "Token has already been staked");
            nftToken.tokenFreeze(tokensId[i]);
            depositedRobiBoost += robiBoost;
            userInfo[msg.sender].stakedTokensId.push(tokensId[i]);
        }
        if(depositedRobiBoost > 0){
            userInfo[msg.sender].stakedRbAmount += depositedRobiBoost;
            totalRBSupply += depositedRobiBoost;
        }
        _updateRewardDebt(msg.sender);
        emit StakeTokens(msg.sender, depositedRobiBoost, tokensId);
    }

    // Withdraw _NFT tokens from STAKING.
    //BNF-02, SFR-02
    function unstake(uint[] calldata tokensId) public nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.stakedTokensId.length >= tokensId.length, "Wrong token count given");
        uint withdrawalRBAmount = 0;
        _withdrawReward();
        bool findToken;
        for(uint i = 0; i < tokensId.length; i++){
            findToken = false;
            for(uint j = 0; j < user.stakedTokensId.length; j++){
                if(tokensId[i] == user.stakedTokensId[j]){
                    removeTokenIdFromUserInfo(j, msg.sender);
                    withdrawalRBAmount += nftToken.getRB(tokensId[i]);
                    nftToken.tokenUnfreeze(tokensId[i]);
                    findToken = true;
                    break;
                }
            }
            require(findToken, "Token not staked by user");
        }
        if(withdrawalRBAmount > 0){
            user.stakedRbAmount -= withdrawalRBAmount;
            totalRBSupply -= withdrawalRBAmount;
            _updateRewardDebt(msg.sender);
        }
        emit UnstakeToken(msg.sender, withdrawalRBAmount, tokensId);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyUnstake() public {
        uint[] memory tokensId = userInfo[msg.sender].stakedTokensId;
        totalRBSupply -= userInfo[msg.sender].stakedRbAmount;
        delete userInfo[msg.sender];
        for(uint i = 0; i < listRewardTokens.length; i++){
            delete rewardDebt[msg.sender][listRewardTokens[i]];
        }
        for(uint i = 0; i < tokensId.length; i++){
            nftToken.tokenUnfreeze(tokensId[i]);
        }
        emit EmergencyWithdraw(msg.sender, tokensId.length);
    }

    // Withdraw reward token. EMERGENCY ONLY.
    function emergencyRewardTokenWithdraw(address _token, uint256 _amount) public onlyOwner {
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Not enough balance");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}
