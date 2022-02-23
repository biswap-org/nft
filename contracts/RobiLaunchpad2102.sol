//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
 * @notice Biswap NFT interface
 */
interface IBiswapNFT {
    function launchpadMint(address to, uint level, uint robiBoost) external;
}

interface IautoBsw {
    function balanceOf() external view returns(uint);
    function totalShares() external view returns(uint);

    struct UserInfo {
        uint shares; // number of shares for a user
        uint lastDepositedTime; // keeps track of deposited time for potential penalty
        uint BswAtLastUserAction; // keeps track of Bsw deposited at the last user action
        uint lastUserActionTime; // keeps track of the last user action time
    }

    function userInfo(address user) external view returns (UserInfo memory);
}


contract RobiLaunchpad2102 is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    IBiswapNFT biswapNFT;
    address public treasuryAddress;
    IERC20 public immutable dealToken;
    IautoBsw public autoBsw;

    uint public price;
    uint public minStakeAmount;
    uint public startBlock;
    uint public totalCount;
    uint public soldCount;
    uint public maxToUser;
    uint public nftLevel;

    struct Brackets {
        uint32 count;
        uint128 robiBoost;
    }

    struct UserInfo {
        uint price;
        uint minStakeAmount;
        uint startBlock;
        uint totalCount;
        uint soldCount;
        uint maxToUser;
        uint boughtCount;
        uint stakedAmount;
    }
    Brackets[10] public brackets;
    mapping(address => uint) public boughtCount; //Bought NFT`s by user: address => tickets count

    event LaunchpadExecuted(address indexed user, uint robiboost);

    constructor(
        IBiswapNFT _biswapNFT,
        IERC20 _dealToken,
        address _treasuryAddress,
        uint _startBlock,
        IautoBsw _autoBsw
    ) {
        require(_startBlock > block.number, "Setting start to the past not allowed");
        require(_treasuryAddress != address(0), "Setting zero address as teasury not allowed");
        require(address(_biswapNFT) != address(0), "Setting zero address as _biswapNFT not allowed");

        biswapNFT = _biswapNFT;
        autoBsw = _autoBsw;
        dealToken = _dealToken;
        treasuryAddress = _treasuryAddress;

        totalCount = 5000;
        minStakeAmount = 100 ether;
        startBlock = _startBlock;
        price = 50 ether;
        maxToUser = 6;
        nftLevel = 1;

        brackets[0].count = 200;
        brackets[0].robiBoost = 1 ether;

        brackets[1].count = 600;
        brackets[1].robiBoost = 2 ether;

        brackets[2].count = 600;
        brackets[2].robiBoost = 3 ether;

        brackets[3].count = 750;
        brackets[3].robiBoost = 4 ether;

        brackets[4].count = 1000;
        brackets[4].robiBoost = 5 ether;

        brackets[5].count = 600;
        brackets[5].robiBoost = 6 ether;

        brackets[6].count = 600;
        brackets[6].robiBoost = 7 ether;

        brackets[7].count = 350;
        brackets[7].robiBoost = 8 ether;

        brackets[8].count = 200;
        brackets[8].robiBoost = 9 ether;

        brackets[9].count = 100;
        brackets[9].robiBoost = 10 ether;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    function getRandomResultRb() private returns(uint) {
        Brackets[10] memory _brackets = brackets;
        uint min = 1;
        uint max = totalCount - soldCount;
        uint diff = (max - min) + 1;
        uint random = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft(), soldCount))) % diff + min;
        uint rb = 0;
        uint count = 0;
        for(uint i = 0; i < _brackets.length; i++){
            count += _brackets[i].count;
            if(random <= count){
                brackets[i].count -= 1;
                rb = _brackets[i].robiBoost;
                break;
            }
        }
        require(rb > 0, "Wrong rb amount");
        return(rb);
    }

    function getInfo(address _user) public view returns(UserInfo memory userInfo){
        userInfo.stakedAmount = autoBsw.balanceOf() * autoBsw.userInfo(_user).shares / autoBsw.totalShares();
        userInfo.startBlock = startBlock;
        userInfo.minStakeAmount = minStakeAmount;
        userInfo.maxToUser = maxToUser;
        userInfo.boughtCount = _user != address(0) ? boughtCount[_user] : 0;
        userInfo.price = price;
        userInfo.soldCount = soldCount;
        userInfo.totalCount = totalCount;
        return userInfo;
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        require(_treasuryAddress != address(0), "Cant set zero address");
        treasuryAddress = _treasuryAddress;
    }

    function updateSettings(uint _price, uint _minStakeAmount, uint  _startBlock, uint _maxToUser) public onlyOwner {
        price = _price;
        minStakeAmount = _minStakeAmount;
        startBlock = _startBlock;
        maxToUser = _maxToUser;
    }

    function leftToSell() public view returns (uint){
        return totalCount - soldCount;
    }

    function buyNFT() public nonReentrant whenNotPaused notContract {
        require(block.number >= startBlock, "Not started yet");
        require(_checkMinStakeAmount(msg.sender), "Need more staked BSW");
        require(checkLimits(msg.sender), "limit exceeding");

        dealToken.safeTransferFrom(msg.sender, treasuryAddress, price);
        boughtCount[msg.sender] += 1;
        uint rb = getRandomResultRb();
        soldCount += 1;
        biswapNFT.launchpadMint(msg.sender, nftLevel, rb);

        emit LaunchpadExecuted(msg.sender, rb);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function checkLimits(address _user) internal view returns (bool){
        return boughtCount[_user] < maxToUser && soldCount < totalCount;
    }

    function _checkMinStakeAmount(address _user) internal view returns (bool) {
        uint autoBswBalance = autoBsw.balanceOf() * autoBsw.userInfo(_user).shares / autoBsw.totalShares();
        return autoBswBalance >= minStakeAmount;
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
