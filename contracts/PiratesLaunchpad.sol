//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './interfaces/IAutoBSW.sol';

interface INFT {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
    function tokenByIndex(uint256 index) external view returns (uint256);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function balanceOf(address owner) external view returns (uint256 balance);
}


contract PiratesLaunchpad is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct InstanceNFT {
        INFT NFT;
        address vault;
    }

    struct Bracket {
        uint[] instances;
        uint totalCount;
    }

    struct UserInfoFrontend {
        uint price;
        uint boughtCount;
        uint totalCount;
        uint soldCount;
        uint minStakeAmount;
        uint autoBswBalance;
        uint startBlock;
        bool inQueue;
        bool canCloseQueue;
    }

    struct Queue {
        address caller;
        uint blockNumber;
    }

    IERC20 public dealToken;
    IAutoBSW public autoBsw;
    address public treasuryAddress;

    uint   public priceInDealToken;
    uint   public minStakeAmount;
    uint   public launchStartBlock;
    uint32 public totalCount;
    uint32 public soldCount;

    Bracket[4] public brackets;
    Queue[] public queue;

    mapping(uint => InstanceNFT) public instances;
    mapping(address => uint) public boughtCount; //Bought brackets by user: address => brackets count
    mapping(address => bool) public userInQueue;

    event QueueExecuted(address indexed user, uint bracketIndex, address[] nfts, string[] uris);
    event InstanceNFTUpdated(uint index,  INFT nft, address vault);

    modifier notContract() {
        require(address(msg.sender).code.length == 0, "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    constructor(
        IERC20 _dealToken,
        IAutoBSW _autoBsw,
        address _treasuryAddress,
        uint _launchStartBlock,
        uint _priceInDealToken
    ) {
        require(_launchStartBlock > block.number, "Setting start to the past not allowed");
        require(address(_dealToken) != address(0), "Setting zero address as _dealToken not allowed");
        require(address(_autoBsw)   != address(0), "Setting zero address as _autoBsw not allowed");
        require(_treasuryAddress != address(0), "Setting zero address as _treasuryAddress not allowed");

        dealToken        = _dealToken;
        autoBsw          = _autoBsw;
        treasuryAddress  = _treasuryAddress;
        priceInDealToken = _priceInDealToken;
        launchStartBlock = _launchStartBlock;
        minStakeAmount   = 100 ether;
        totalCount       = 5000;
        soldCount        = 0;

        //Add brackets
        brackets[0].instances.push(0);
        brackets[0].instances.push(2);
        brackets[0].totalCount = 2446;
        brackets[1].instances.push(1);
        brackets[1].instances.push(2);
        brackets[1].totalCount = 2455;
        brackets[2].instances.push(0);
        brackets[2].instances.push(2);
        brackets[2].instances.push(3);
        brackets[2].totalCount = 49;
        brackets[3].instances.push(1);
        brackets[3].instances.push(2);
        brackets[3].instances.push(3);
        brackets[3].totalCount = 50;
    }

    // 0 - pirates
    // 1 - ships
    // 2 - art
    // 3 - sandBox

    function updateInstanceOfNFT(uint _index, INFT _NFT, address _vault) public onlyOwner {
        require(address(_NFT)  != address(0) && _vault != address(0), "Address cant be zero");
        instances[_index].NFT = _NFT;
        instances[_index].vault = _vault;

        emit InstanceNFTUpdated(_index, _NFT, _vault);
    }

    function getUserInfo(address _user) public view returns (UserInfoFrontend memory){
        UserInfoFrontend memory _userInfo;

        _userInfo.price = priceInDealToken;
        _userInfo.startBlock = launchStartBlock;
        _userInfo.boughtCount    = boughtCount[_user];
        _userInfo.totalCount     = totalCount;
        _userInfo.soldCount      = soldCount;
        _userInfo.minStakeAmount = minStakeAmount;
        _userInfo.autoBswBalance = autoBsw.balanceOf() * autoBsw.userInfo(_user).shares / autoBsw.totalShares();
        _userInfo.inQueue = userInQueue[_user];
        uint queueIndex = getUserQueueIndex(_user);
        _userInfo.canCloseQueue = queueIndex < queue.length && queue[queueIndex].blockNumber < block.number ? true : false;
        return _userInfo;
    }

    function getUserQueueIndex(address _user) public view returns(uint){
        for(uint i = 0; i < queue.length; i++){
            if(queue[i].caller == _user){
                return i;
            }
        }
        return queue.length;
    }

    function getQueueSize() public view returns(uint){
        return queue.length;
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        require(_treasuryAddress != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
    }

    function updateStartTimestamp(uint _startBlock) public onlyOwner {
        require(_startBlock > block.number, "Setting start to the past not allowed");
        launchStartBlock = _startBlock;
    }

    function leftToSell() public view returns (uint){
        return totalCount - soldCount - queue.length;
    }

    function manuallyCloseQueue(uint _limit) public onlyOwner {
        uint queueLength = queue.length;
        if(queueLength == 0) return;
        _limit = _limit == 0 || _limit > queueLength ? queueLength : _limit;
        uint i = 0;
        while(i < _limit){
            if (_executeQueue(i)) {
                _limit--;
            } else {
                i++;
                continue;
            }
        }
    }

    function buyNFT() public nonReentrant whenNotPaused notContract {
        if(userInQueue[msg.sender]){
            selfExecuteQueue();
            return;
        }
        require(block.number >= launchStartBlock, "Not started yet");
        require(_checkMinStakeAmount(msg.sender), "Need more staked BSW");
        require(checkLimits(), "limit exceeding");

        boughtCount[msg.sender] += 1;

        dealToken.safeTransferFrom(msg.sender, treasuryAddress, priceInDealToken);

        pushToQueue(msg.sender);
    }

    function selfExecuteQueue() public whenNotPaused notContract returns(bool){
        for(uint i = 0; i < queue.length; i++){
            if(queue[i].caller == msg.sender){
                return _executeQueue(i);
            }
        }
        revert("User isnt in Queue");
    }

    function pushToQueue(address _user) private {
        require(!userInQueue[_user], "User already in Queue");
        userInQueue[_user] = true;
        queue.push(Queue(_user, block.number));
    }

    function _executeQueue(uint _index) internal returns(bool){
        require(_index < queue.length, "Index out of bound");
        Queue memory _queue = queue[_index];
        if(block.number <= _queue.blockNumber) return false;
        if(block.number - _queue.blockNumber > 255){
            queue[_index].blockNumber = block.number;
            return false;
        }
        queue[_index] = queue[queue.length - 1];
        queue.pop();
        bytes32 _hash = keccak256(abi.encodePacked(blockhash(_queue.blockNumber), _queue.caller));
        uint bracketIndex = _getRandomBracket(_hash);
        (string[] memory uris, address[] memory nfts) = _executeBracket(bracketIndex, _queue.caller,  _hash);
        soldCount++;
        userInQueue[_queue.caller] = false;
        emit QueueExecuted(_queue.caller, bracketIndex, nfts, uris);
        return true;
    }

    function _executeBracket(uint _bracketIndex, address _caller, bytes32 _hash) private returns(string[] memory uris, address[] memory nfts) {
        require(_bracketIndex < brackets.length, "Bracket index out of bound");
        Bracket memory _braket = brackets[_bracketIndex];
        uris = new string[](_braket.instances.length);
        nfts = new address[](_braket.instances.length);
        for(uint i = 0; i < _braket.instances.length; i++){
            InstanceNFT memory currentInstance = instances[_braket.instances[i]];
            uint tokenId = _getRandomTokenId(currentInstance, _hash);
            currentInstance.NFT.safeTransferFrom(currentInstance.vault, _caller, tokenId);
            uris[i] = currentInstance.NFT.tokenURI(tokenId);
            nfts[i] = address(currentInstance.NFT);
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function checkLimits() internal view returns (bool){
        return soldCount + queue.length < totalCount;
    }

    function _checkMinStakeAmount(address _user) internal view returns (bool) {
        uint autoBswBalance = autoBsw.balanceOf() * autoBsw.userInfo(_user).shares / autoBsw.totalShares();
        return autoBswBalance >= minStakeAmount;
    }

    // view func to view result by user queue
    function _rand(uint _max, bytes32 _hash) private pure returns(uint randomNumber){
        return uint(_hash) % _max;
    }

    function _getRandomTokenId(
        InstanceNFT memory instance,
        bytes32 _hash
    ) view private returns(uint){
        return instance.NFT.tokenOfOwnerByIndex(instance.vault, _rand(instance.NFT.balanceOf(instance.vault), _hash));
    }

    function _getRandomBracket(bytes32 _hash) private returns(uint bracketIndex) {
        uint random = _rand(leftToSell(), _hash);
        uint count = 0;
        for(uint i = 0; i < brackets.length; i++){
            count += brackets[i].totalCount;
            if(random < count){
                brackets[i].totalCount--;
                return i;
            }
        }
        revert("Wrong random number generate");
    }
}
