//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

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
 * @notice Oracle interface
 */
interface IOracle {
    function consult(address tokenIn, uint amountIn, address tokenOut) external view returns (uint amountOut);
}

/**
 * @notice Wrapped BNB interface
 */
interface IWBNB {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

/**
 * @title Biswap NFT Launchpad
 * @notice Pre-market sell Biswap NFT tokens.
 */
contract LaunchpadNFT is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    IBiswapNFT biswapNFT;
    IOracle oracle;
    address payable public treasuryAddress;
    address public immutable usdt;
    IWBNB public immutable wbnb;

    struct Launchpad {
        uint priceInUSD;
        uint robiBoost;
        uint32 totalCount;
        uint32 soldCount;
        uint32 level;
        uint32 maxToUser;
    }
    Launchpad[] public launches;
    mapping(address => bool) public whitelistDealToken; //deal token white list
    mapping(address => mapping(uint => uint)) public boughtCount; //Bought NFT`s by user: address => launches => tickets count

    event ConfigWhitelistDealToken(address indexed token, bool enabled);
    event LaunchpadExecuted(address indexed user, address indexed dealToken, uint launchIndex);

    /**
     * @notice Constructor
     * @dev In constructor initialise launches
     * @param _biswapNFT: Biswap NFT interface
     * @param _oracle: price oracle
     * @param _wbnb: wrapped BNB contract
     * @param _usdt: USDT ERC20 contract
     */
    constructor(IBiswapNFT _biswapNFT, IOracle _oracle, IWBNB _wbnb, address _usdt) {
        biswapNFT = _biswapNFT;
        oracle = _oracle;
        wbnb = _wbnb;
        usdt = _usdt;
        treasuryAddress = payable(msg.sender);
        launches.push(
            Launchpad({
        totalCount: 2500,
        soldCount: 0,
        priceInUSD: 10 ether,
        level: 1,
        robiBoost: 1e18,
        maxToUser: 6
        })
        );
        launches.push(
            Launchpad({
        totalCount: 250,
        soldCount: 0,
        priceInUSD: 200 ether,
        level: 2,
        robiBoost: 66e18,
        maxToUser: 1
        })
        );
        launches.push(
            Launchpad({
        totalCount: 50,
        soldCount: 0,
        priceInUSD: 1000 ether,
        level: 3,
        robiBoost: 550e18,
        maxToUser: 1
        })
        );
        launches.push(
            Launchpad({
        totalCount: 10,
        soldCount: 0,
        priceInUSD: 6000 ether,
        level: 4,
        robiBoost: 4400e18,
        maxToUser: 1
        })
        );
        launches.push(
            Launchpad({
        totalCount: 1,
        soldCount: 0,
        priceInUSD: 40000 ether,
        level: 5,
        robiBoost: 33000e18,
        maxToUser: 1
        })
        );
    }

    /**
     * @notice Add new deal token ERC20 to white list
     * @dev Callable by contract owner
     * @param _dealToken: ERC20 token contract address
     */
    function setWhitelistDealToken(address _dealToken) public onlyOwner {
        require(_dealToken != address(0), "Must be non zero");
        whitelistDealToken[_dealToken] = true;
        emit ConfigWhitelistDealToken(_dealToken, true);
    }

    /**
     * @notice Remove deal token ERC20 from white list
     * @dev Callable by contract owner
     * @param _dealToken: ERC20 token contract address
     */
    function delWhitelistDealToken(address _dealToken) public onlyOwner {
        require(_dealToken != address(0), "Must be non zero");
        whitelistDealToken[_dealToken] = false;
        emit ConfigWhitelistDealToken(_dealToken, false);
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
     * @param _priceInUSD: price in USDT for 1 token
     * @param _level: NFT token level
     * @param _robiBoost: NFT token Robi Boost
     * @param _maxToUser: max NFT tokens limit for sale to one user
    */
    function addNewLaunch(uint32 _totalCount, uint _priceInUSD, uint32 _level, uint _robiBoost, uint32 _maxToUser) public onlyOwner {
        require(_totalCount > 0, "count must be greater than zero");
        require(_maxToUser > 0, "");
        require(_level < 7, "Incorrect level");
        launches.push(
            Launchpad({
        totalCount: _totalCount,
        soldCount: 0,
        priceInUSD: _priceInUSD,
        level: _level,
        robiBoost: _robiBoost,
        maxToUser: _maxToUser
        })
        );
    }

    /**
     * @notice Get how many tokens left to sell from launch
     * @dev Callable by users
     * @param _index: Index of launch
     * @return number of tokens left to sell from launch
     */
    function leftToSell(uint _index) public view returns(uint){
        require(_index <= launches.length, "Wrong index");
        return launches[_index].totalCount - launches[_index].soldCount;
    }

    /**
     * @notice Get launch NFT token price in deal token
     * @param _dealToken: deal token
     * @param _launchIndex: launch index
     */
    function getPriceInToken(address _dealToken, uint _launchIndex) public view returns(uint){
        require(_launchIndex < launches.length, "Wrong index");
        return oracle.consult(usdt, launches[_launchIndex].priceInUSD, _dealToken);
    }

    /**
     * @notice Buy Biswap NFT token from launch
     * @dev Callable by user
     * @param _launchIndex: Index of launch
     * @param _dealToken: Purchase ERC20 token
     */
    function buyNFT(uint _launchIndex, address _dealToken)
    public
    payable
    nonReentrant
    whenNotPaused
    _dealTokenInWhitelist(_dealToken)
    {
        require(_launchIndex < launches.length, "Wrong launchpad number");

        Launchpad storage _launch = launches[_launchIndex];
        require(checkLimits(msg.sender, _launchIndex), "limit exceeding");
        boughtCount[msg.sender][_launchIndex] += 1;
        _launch.soldCount += 1;
        uint price = _dealToken == usdt ?
        _launch.priceInUSD :
        oracle.consult(usdt, _launch.priceInUSD, _dealToken);

        require(price > 0, "Wrong price given");

        if(_dealToken == address(wbnb) && msg.value >= price){
            (bool success, ) = treasuryAddress.call{value:msg.value}("");
            require(success, "Can`t transfer funds");
        } else {
            IERC20(_dealToken).safeTransferFrom(msg.sender, treasuryAddress, price);
        }
        biswapNFT.launchpadMint(msg.sender, _launch.level, _launch.robiBoost);
        emit LaunchpadExecuted(msg.sender, _dealToken, _launchIndex);
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
    function checkLimits(address user, uint launchIndex) internal view returns(bool){
        Launchpad memory launch = launches[launchIndex];
        return boughtCount[user][launchIndex] < launch.maxToUser &&
        launch.soldCount < launch.totalCount;
    }

    modifier _dealTokenInWhitelist(address _dealToken) {
        require(whitelistDealToken[_dealToken], "Token not allowed");
        _;
    }

}
