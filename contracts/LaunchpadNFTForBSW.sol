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
contract LaunchpadNftForBSW is ReentrancyGuard, Ownable, Pausable {
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

    Launchpad[] public launches;
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
                totalCount : 2500,
                soldCount : 0,
                price : 10 ether,
                level : 1,
                robiBoost : 1e18,
                maxToUser : 6
            })
        );
        launches.push(
            Launchpad({
                totalCount : 250,
                soldCount : 0,
                price : 200 ether,
                level : 2,
                robiBoost : 66e18,
                maxToUser : 1
            })
        );
        launches.push(
            Launchpad({
                totalCount : 50,
                soldCount : 0,
                price : 1000 ether,
                level : 3,
                robiBoost : 550e18,
                maxToUser : 1
            })
        );
        launches.push(
            Launchpad({
                totalCount : 10,
                soldCount : 0,
                price : 6000 ether,
                level : 4,
                robiBoost : 4400e18,
                maxToUser : 1
            })
        );
        launches.push(
            Launchpad({
                totalCount : 1,
                soldCount : 0,
                price : 40000 ether,
                level : 5,
                robiBoost : 33000e18,
                maxToUser : 1
            })
        );
    }

    /**
     * @notice Set treasury address to accumulate deal tokens from sells
     * @dev Callable by contract owner
     * @param _treasuryAddress: Treasury address
     */
    function setTreasuryAddress(address payable _treasuryAddress) public onlyOwner {
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
    function buyNFT(uint _launchIndex)public nonReentrant whenNotPaused {
        require(_launchIndex < launches.length, "Wrong launchpad number");

        Launchpad storage _launch = launches[_launchIndex];
        require(checkLimits(msg.sender, _launchIndex), "limit exceeding");
        boughtCount[msg.sender][_launchIndex] += 1;
        _launch.soldCount += 1;

        dealToken.safeTransferFrom(msg.sender, treasuryAddress, _launch.price);

        biswapNFT.launchpadMint(msg.sender, _launch.level, _launch.robiBoost);

        emit LaunchpadExecuted(msg.sender, _launchIndex, _launch.robiBoost);
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
}
