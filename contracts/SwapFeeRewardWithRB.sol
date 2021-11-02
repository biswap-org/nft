pragma solidity 0.6.6;

import "./Ownable.sol";
import "./libs/SafeMath.sol";
import "./libs/EnumerableSet.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOracle.sol";

interface IBSWFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function INIT_CODE_HASH() external pure returns (bytes32);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;

    function setDevFee(address pair, uint8 _devFee) external;

    function setSwapFee(address pair, uint32 swapFee) external;
}

interface IBSWPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function swapFee() external view returns (uint32);

    function devFee() external view returns (uint32);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;

    function setSwapFee(uint32) external;

    function setDevFee(uint32) external;
}

interface IBswToken is IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external override returns (bool);
}

interface IBiswapNFT {
    function accrueRB(address user, uint amount) external;
    function tokenFreeze(uint tokenId) external;
    function tokenUnfreeze(uint tokenId) external;
    function getRB(uint tokenId) external view returns(uint);
    function getInfoForStaking(uint tokenId) external view returns(address tokenOwner, bool stakeFreeze, uint robiBoost);
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() public {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}


contract SwapFeeRewardWithRB is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _whitelist;

    address public factory;
    address public router;
    address public market;
    address public auction;
    bytes32 public INIT_CODE_HASH;
    uint256 public maxMiningAmount = 100000000 ether;
    uint256 public maxMiningInPhase = 5000 ether;
    uint public maxAccruedRBInPhase = 5000 ether;

    uint public currentPhase = 1;
    uint public currentPhaseRB = 1;
    uint256 public totalMined = 0;
    uint public totalAccruedRB = 0;
    uint public rbWagerOnSwap = 1500; //Wager of RB
    uint public rbPercentMarket = 10000; // (div 10000)
    uint public rbPercentAuction = 10000; // (div 10000)
    IBswToken public bswToken;
    IOracle public oracle;
    IBiswapNFT public biswapNFT;
    address public targetToken;
    address public targetRBToken;
    uint public defaultFeeDistribution = 90;

    mapping(address => uint) public nonces;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) public pairOfPid;

    //percent of distribution between feeReward and robiBoost [0, 90] 0 => 90% feeReward and 10% robiBoost; 90 => 100% robiBoost
    //calculate: defaultFeeDistribution (90) - feeDistibution = feeReward
    mapping(address => uint) public feeDistribution;

    struct PairsList {
        address pair;
        uint256 percentReward;
        bool enabled;
    }

    PairsList[] public pairsList;

    event Withdraw(address userAddress, uint256 amount);
    event Rewarded(address account, address input, address output, uint256 amount, uint256 quantity);
    //BNF-01, SFR-01
    event NewRouter(address);
    event NewFactory(address);
    event NewMarket(address);
    event NewPhase(uint);
    event NewPhaseRB(uint);
    event NewAuction(address);
    event NewBiswapNFT(IBiswapNFT);
    event NewOracle(IOracle);

    modifier onlyRouter() {
        require(msg.sender == router, "SwapFeeReward: caller is not the router");
        _;
    }

    modifier onlyMarket() {
        require(msg.sender == market, "SwapFeeReward: caller is not the market");
        _;
    }

    modifier onlyAuction() {
        require(msg.sender == auction, "SwapFeeReward: caller is not the auction");
        _;
    }

    constructor(
        address _factory,
        address _router,
        bytes32 _INIT_CODE_HASH,
        IBswToken _bswToken,
        IOracle _Oracle,
        IBiswapNFT _biswapNFT,
        address _targetToken,
        address _targetRBToken

    ) public {
        //SFR-03
        require(
            _factory != address(0)
            && _router != address(0)
            && _targetToken != address(0)
            && _targetRBToken != address(0),
            "Address can not be zero"
        );
        factory = _factory;
        router = _router;
        INIT_CODE_HASH = _INIT_CODE_HASH;
        bswToken = _bswToken;
        oracle = _Oracle;
        targetToken = _targetToken;
        biswapNFT = _biswapNFT;
        targetRBToken = _targetRBToken;
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, "BSWSwapFactory: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "BSWSwapFactory: ZERO_ADDRESS");
    }

    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                INIT_CODE_HASH
            ))));
    }

    function getSwapFee(address tokenA, address tokenB) internal view returns (uint swapFee) {
        //SFR-05
        swapFee = uint(1000).sub(IBSWPair(pairFor(tokenA, tokenB)).swapFee());
    }

    function setPhase(uint _newPhase) public onlyOwner returns (bool){
        currentPhase = _newPhase;
        //BNF-01, SFR-01
        emit NewPhase(_newPhase);
        return true;
    }

    function setPhaseRB(uint _newPhase) public onlyOwner returns (bool){
        currentPhaseRB = _newPhase;
        //BNF-01, SFR-01
        emit NewPhaseRB(_newPhase);
        return true;
    }

    function checkPairExist(address tokenA, address tokenB) public view returns (bool) {
        address pair = pairFor(tokenA, tokenB);
        PairsList storage pool = pairsList[pairOfPid[pair]];
        if (pool.pair != pair) {
            return false;
        }
        return true;
    }

    function feeCalculate(address account, address input, address output, uint256 amount)
    public
    view
    returns(
        uint feeReturnInBSW,
        uint feeReturnInUSD,
        uint robiBoostAccrue
    )
    {

        uint256 pairFee = getSwapFee(input, output);
        address pair = pairFor(input, output);
        PairsList memory pool = pairsList[pairOfPid[pair]];
        if (pool.pair != pair || pool.enabled == false || !isWhitelist(input) || !isWhitelist(output)) {
            feeReturnInBSW = 0;
            feeReturnInUSD = 0;
            robiBoostAccrue = 0;
        } else {
            (uint feeAmount, uint rbAmount) = calcAmounts(amount, account);
            uint256 fee = feeAmount.div(pairFee);
            uint256 quantity = getQuantity(output, fee, targetToken);
            feeReturnInBSW = quantity.mul(pool.percentReward).div(100);
            robiBoostAccrue = getQuantity(output, rbAmount.div(rbWagerOnSwap), targetRBToken);
            feeReturnInUSD = getQuantity(targetToken, feeReturnInBSW, targetRBToken);
        }
    }

    function swap(address account, address input, address output, uint256 amount) public onlyRouter returns (bool) {
        if (!isWhitelist(input) || !isWhitelist(output)) {
            return false;
        }
        address pair = pairFor(input, output);
        PairsList memory pool = pairsList[pairOfPid[pair]];
        if (pool.pair != pair || pool.enabled == false) {
            return false;
        }
        uint256 pairFee = getSwapFee(input, output);
        (uint feeAmount, uint rbAmount) = calcAmounts(amount, account);
        uint256 fee = feeAmount.div(pairFee);
        rbAmount = rbAmount.div(rbWagerOnSwap);
        //SFR-05
        _accrueRB(account, output, rbAmount);

        uint256 quantity = getQuantity(output, fee, targetToken);
        quantity = quantity.mul(pool.percentReward).div(100);
        if (maxMiningAmount >= totalMined.add(quantity)) {
            if (totalMined.add(quantity) <= currentPhase.mul(maxMiningInPhase)) {
                _balances[account] = _balances[account].add(quantity);
                emit Rewarded(account, input, output, amount, quantity);
            }
        }
        return true;
    }

    function calcAmounts(uint amount, address account) internal view returns(uint feeAmount, uint rbAmount){
        feeAmount = amount.mul(defaultFeeDistribution.sub(feeDistribution[account])).div(100);
        rbAmount = amount.sub(feeAmount);
    }

    function accrueRBFromMarket(address account, address fromToken, uint amount) public onlyMarket {
        //SFR-05
        amount = amount.mul(rbPercentMarket).div(10000);
        _accrueRB(account, fromToken, amount);
    }

    function accrueRBFromAuction(address account, address fromToken, uint amount) public onlyAuction {
        //SFR-05
        amount = amount.mul(rbPercentAuction).div(10000);
        _accrueRB(account, fromToken, amount);
    }

    //SFR-05
    function _accrueRB(address account, address output, uint amount) private {
        uint quantity = getQuantity(output, amount, targetRBToken);
        if (quantity > 0) {
            //SFR-06
            totalAccruedRB = totalAccruedRB.add(quantity);
            if(totalAccruedRB <= currentPhaseRB.mul(maxAccruedRBInPhase)){
                biswapNFT.accrueRB(account, quantity);
            }
        }
    }

    function rewardBalance(address account) public view returns (uint256){
        return _balances[account];
    }

    function permit(address spender, uint value, uint8 v, bytes32 r, bytes32 s) private {
        bytes32 message = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(spender, value, nonces[spender]++))));
        address recoveredAddress = ecrecover(message, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == spender, "SwapFeeReward: INVALID_SIGNATURE");
    }

    //BNF-02, SCN-01, SFR-02
    function withdraw(uint8 v, bytes32 r, bytes32 s) public nonReentrant returns (bool){
        require(maxMiningAmount > totalMined, "SwapFeeReward: Mined all tokens");
        uint256 balance = _balances[msg.sender];
        require(totalMined.add(balance) <= currentPhase.mul(maxMiningInPhase), "SwapFeeReward: Mined all tokens in this phase");
        permit(msg.sender, balance, v, r, s);
        if (balance > 0) {
            _balances[msg.sender] = _balances[msg.sender].sub(balance);
            totalMined = totalMined.add(balance);
            //SFR-04
            if(bswToken.transfer(msg.sender, balance)){
                emit Withdraw(msg.sender, balance);
                return true;
            }
        }
        return false;
    }

    function getQuantity(address outputToken, uint256 outputAmount, address anchorToken) public view returns (uint256) {
        uint256 quantity = 0;
        if (outputToken == anchorToken) {
            quantity = outputAmount;
        } else if (IBSWFactory(factory).getPair(outputToken, anchorToken) != address(0) && checkPairExist(outputToken, anchorToken)) {
            quantity = IOracle(oracle).consult(outputToken, outputAmount, anchorToken);
        } else {
            uint256 length = getWhitelistLength();
            for (uint256 index = 0; index < length; index++) {
                address intermediate = getWhitelist(index);
                if (IBSWFactory(factory).getPair(outputToken, intermediate) != address(0) && IBSWFactory(factory).getPair(intermediate, anchorToken) != address(0) && checkPairExist(intermediate, anchorToken)) {
                    uint256 interQuantity = IOracle(oracle).consult(outputToken, outputAmount, intermediate);
                    quantity = IOracle(oracle).consult(intermediate, interQuantity, anchorToken);
                    break;
                }
            }
        }
        return quantity;
    }

    function addWhitelist(address _addToken) public onlyOwner returns (bool) {
        require(_addToken != address(0), "SwapMining: token is the zero address");
        return EnumerableSet.add(_whitelist, _addToken);
    }

    function delWhitelist(address _delToken) public onlyOwner returns (bool) {
        require(_delToken != address(0), "SwapMining: token is the zero address");
        return EnumerableSet.remove(_whitelist, _delToken);
    }

    function getWhitelistLength() public view returns (uint256) {
        return EnumerableSet.length(_whitelist);
    }

    function isWhitelist(address _token) public view returns (bool) {
        return EnumerableSet.contains(_whitelist, _token);
    }

    function getWhitelist(uint256 _index) public view returns (address){
        //SFR-06
        require(_index <= getWhitelistLength().sub(1), "SwapMining: index out of bounds");
        return EnumerableSet.at(_whitelist, _index);
    }

    function setRouter(address newRouter) public onlyOwner {
        require(newRouter != address(0), "SwapMining: new router is the zero address");
        router = newRouter;
        //BNF-01, SFR-01
        emit NewRouter(newRouter);
    }

    function setMarket(address _market) public onlyOwner {
        require(_market != address(0), "SwapMining: new market is the zero address");
        market = _market;
        //BNF-01, SFR-01
        emit NewMarket(_market);
    }

    function setAuction(address _auction) public onlyOwner {
        require(_auction != address(0), "SwapMining: new auction is the zero address");
        auction = _auction;
        //BNF-01, SFR-01
        emit NewAuction(_auction);
    }

    function setBiswapNFT(IBiswapNFT _biswapNFT) public onlyOwner {
        require(address(_biswapNFT) != address(0), "SwapMining: new biswapNFT is the zero address");
        biswapNFT = _biswapNFT;
        //BNF-01, SFR-01
        emit NewBiswapNFT(_biswapNFT);
    }

    function setOracle(IOracle _oracle) public onlyOwner {
        require(address(_oracle) != address(0), "SwapMining: new oracle is the zero address");
        oracle = _oracle;
        //BNF-01, SFR-01
        emit NewOracle(_oracle);
    }

    function setFactory(address _factory) public onlyOwner {
        require(_factory != address(0), "SwapMining: new factory is the zero address");
        factory = _factory;
        //BNF-01, SFR-01
        emit NewFactory(_factory);
    }

    function setInitCodeHash(bytes32 _INIT_CODE_HASH) public onlyOwner {
        INIT_CODE_HASH = _INIT_CODE_HASH;
    }

    function pairsListLength() public view returns (uint256) {
        return pairsList.length;
    }

    function addPair(uint256 _percentReward, address _pair) public onlyOwner {
        require(_pair != address(0), "_pair is the zero address");
        pairsList.push(
            PairsList({
        pair : _pair,
        percentReward : _percentReward,
        enabled : true
        })
        );
        //SFR-06
        pairOfPid[_pair] = pairsListLength().sub(1);

    }

    function setPair(uint256 _pid, uint256 _percentReward) public onlyOwner {
        pairsList[_pid].percentReward = _percentReward;
    }

    function setPairEnabled(uint256 _pid, bool _enabled) public onlyOwner {
        pairsList[_pid].enabled = _enabled;
    }

    function setRobiBoostReward(uint _rbWagerOnSwap, uint _percentMarket, uint _percentAuction) public onlyOwner {
        rbWagerOnSwap = _rbWagerOnSwap;
        rbPercentMarket = _percentMarket;
        rbPercentAuction = _percentAuction;
    }

    function setFeeDistribution(uint newDistribution) public {
        require(newDistribution <= defaultFeeDistribution, "Wrong fee distribution");
        feeDistribution[msg.sender] = newDistribution;
    }

}