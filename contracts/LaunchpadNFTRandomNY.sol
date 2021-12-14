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

/**
 * @title Biswap NFT Launchpad
 * @notice Pre-market sell Biswap NFT tokens.
 */
contract LaunchpadNftRandomNY is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    IBiswapNFT biswapNFT;
    address public treasuryAddress;
    IERC20 public immutable dealToken;

    struct Launchpad {
        uint price;
        uint robiBoost;
        uint32 totalCount;
        uint32 soldCount;
        uint32 level;
        uint32 maxToUser;
    }

    struct Brackets {
        uint32 count;
        uint128 robiBoost;
    }

    Launchpad[] public launches;
    Brackets[10] public brackets;
    mapping(address => mapping(uint => uint)) public boughtCount; //Bought NFT`s by user: address => launches => tickets count

    event LaunchpadExecuted(address indexed user, uint launchIndex, uint robiboost);

    /**
     * @notice Constructor
     * @dev In constructor initialise launches
     * @param _biswapNFT: Biswap NFT interface
     * @param _dealToken: deal token address
     * @param _treasuryAddress: treasury address
     */
    constructor(IBiswapNFT _biswapNFT, IERC20 _dealToken, address _treasuryAddress) {
        biswapNFT = _biswapNFT;
        dealToken = _dealToken;
        treasuryAddress = _treasuryAddress;
        launches.push(
            Launchpad({
                totalCount : 30000,
                soldCount : 0,
                price : 50 ether,
                level : 1,
                robiBoost : 0,
                maxToUser : 1
            })
        );

        brackets[0].count = 1500;
        brackets[0].robiBoost = 1 ether;
        brackets[1].count = 4500;
        brackets[1].robiBoost = 2 ether;
        brackets[2].count = 4500;
        brackets[2].robiBoost = 3 ether;
        brackets[3].count = 4500;
        brackets[3].robiBoost = 4 ether;
        brackets[4].count = 6000;
        brackets[4].robiBoost = 5 ether;
        brackets[5].count = 3000;
        brackets[5].robiBoost = 6 ether;
        brackets[6].count = 3000;
        brackets[6].robiBoost = 7 ether;
        brackets[7].count = 1500;
        brackets[7].robiBoost = 8 ether;
        brackets[8].count = 900;
        brackets[8].robiBoost = 9 ether;
        brackets[9].count = 600;
        brackets[9].robiBoost = 10 ether;

    }

    /**
     * @notice Checks if the msg.sender is a contract or a proxy
     */
    modifier notContract() {
        require(!_isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    /**
     * @notice Generate random between min and max brackets value. Then find RB value
     */
    function getRandomResultRb() private returns(uint) {
        Brackets[10] memory _brackets = brackets;
        Launchpad memory _launch = launches[0];
        uint min = 1;
        uint max = _launch.totalCount - _launch.soldCount;
        uint diff = (max - min) + 1;
        uint random = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft(), _launch.soldCount))) % diff + min;
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

    /**
     * @notice Set treasury address to accumulate deal tokens from sells
     * @dev Callable by contract owner
     * @param _treasuryAddress: Treasury address
     */
    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        treasuryAddress = _treasuryAddress;
    }

    /**
     * @notice Add new launchpad
     * @dev Callable by contract owner
     * @param _totalCount: number of NFT tokens for sale in current launchpad
     * @param _price: price in deal token for 1 NFT from launchpad
     * @param _level: NFT token level
     * @param _robiBoost: NFT token Robi Boost
     * @param _maxToUser: max NFT tokens limit for sale to one user
    */
    function addNewLaunch(uint32 _totalCount, uint _price, uint32 _level, uint _robiBoost, uint32 _maxToUser) public onlyOwner {
        require(_totalCount > 0, "count must be greater than zero");
        require(_maxToUser > 0, "");
        require(_level < 7, "Incorrect level");
        launches.push(
            Launchpad({
                totalCount : _totalCount,
                soldCount : 0,
                price : _price,
                level : _level,
                robiBoost : _robiBoost,
                maxToUser : _maxToUser
            })
        );
    }

    /**
     * @notice Get how many tokens left to sell from launch
     * @dev Callable by users
     * @param _index: Index of launch
     * @return number of tokens left to sell from launch
     */
    function leftToSell(uint _index) public view returns (uint){
        require(_index <= launches.length, "Wrong index");
        return launches[_index].totalCount - launches[_index].soldCount;
    }

    /**
     * @notice Buy Biswap NFT token from launch
     * @dev Callable by user
     * @param _launchIndex: Index of launch
     */
    function buyNFT(uint _launchIndex) public nonReentrant whenNotPaused notContract {
        require(_launchIndex < launches.length, "Wrong launchpad number");

        Launchpad storage _launch = launches[_launchIndex];
        require(checkLimits(msg.sender, _launchIndex), "limit exceeding");
        boughtCount[msg.sender][_launchIndex] += 1;

        uint rb = getRandomResultRb();
        _launch.soldCount += 1;

        dealToken.safeTransferFrom(msg.sender, treasuryAddress, _launch.price);
        biswapNFT.launchpadMint(msg.sender, _launch.level, rb);

        emit LaunchpadExecuted(msg.sender, _launchIndex, rb);
    }

    /*
     * @notice Pause a contract
     * @dev Callable by contract owner
     */
    function pause() public onlyOwner {
        _pause();
    }

    /*
     * @notice Unpause a contract
     * @dev Callable by contract owner
     */
    function unpause() public onlyOwner {
        _unpause();
    }
    /* @notice Check limits left by user by launch
     * @param user: user address
     * @param launchIndex: index of launchpad
     */
    function checkLimits(address user, uint launchIndex) internal view returns (bool){
        Launchpad memory launch = launches[launchIndex];
        return boughtCount[user][launchIndex] < launch.maxToUser &&
        launch.soldCount < launch.totalCount;
    }

    /**
     * @notice Checks if address is a contract
     * @dev It prevents contract from being targetted
     */
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
