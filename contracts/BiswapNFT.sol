//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
//TODO rename contract
contract BiswapNFT is Initializable, ERC721EnumerableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {

    bytes32 public constant TOKEN_FREEZER = keccak256("TOKEN_FREEZER");
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER");
    bytes32 public constant LAUNCHPAD_TOKEN_MINTER = keccak256("LAUNCHPAD_TOKEN_MINTER");
    bytes32 public constant RB_SETTER_ROLE = keccak256("RB_SETTER");
    uint public constant MAX_ARRAY_LENGTH_PER_REQUEST = 30;

    string private _internalBaseURI;
    uint private _initialRobiBoost;
    uint private _burnRBPeriod; //in days
    uint8 private _levelUpPercent; //in percents
    uint[7] private _rbTable;
    uint[7] private _levelTable;
    uint private _lastTokenId;

    struct Token {
        uint robiBoost;
        uint level;
        bool stakeFreeze; //Lock a token when it is staked
        uint createTimestamp;
    }

    mapping(uint256 => Token) private _tokens;
    mapping(address => mapping(uint => uint)) private _robiBoost;
    mapping(uint => uint) private _robiBoostTotalAmounts;

    event GainRB(uint indexed tokenId, uint newRB);
    event RBAccrued(address user, uint amount);
    event LevelUp(address indexed user, uint indexed newLevel, uint[] parentsTokensId);

    //TODO delete in prod
//    constructor(){
//        initialize("http://", 1000000000000000000, 14);
//        for(uint i; i <= 10; i++){
//            mint(msg.sender);
//        }
//
//    }

    function initialize(
        string memory baseURI,
        uint initialRobiBoost,
        uint burnRBPeriod
    ) public initializer {
        __ERC721_init("BiSwapNFT", "BSWNFT"); //TODO rename token in prod
        __ERC721Enumerable_init();
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _internalBaseURI = baseURI;
        _initialRobiBoost = initialRobiBoost;
        _levelUpPercent = 10; //10%
        _burnRBPeriod = burnRBPeriod;

        _rbTable[0] = 100 ether;
        _rbTable[1] = 10 ether;
        _rbTable[2] = 100 ether;
        _rbTable[3] = 1000 ether;
        _rbTable[4] = 10000 ether;
        _rbTable[5] = 50000 ether;
        _rbTable[6] = 150000 ether;

        _levelTable[0] = 0;
        _levelTable[1] = 6;
        _levelTable[2] = 5;
        _levelTable[3] = 4;
        _levelTable[4] = 3;
        _levelTable[5] = 2;
        _levelTable[6] = 0;

        { //TODO delete in prod
            _setupRole(TOKEN_MINTER_ROLE, msg.sender); //TODO delete in prod
            _setupRole(RB_SETTER_ROLE, msg.sender); //TODO delete in prod

            increaseRobiBoost(msg.sender, block.timestamp/86400, 1000e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 1 days)/86400, 500e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 2 days)/86400, 300e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 3 days)/86400, 800e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 4 days)/86400, 220e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 5 days)/86400, 10e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 6 days)/86400, 13e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 7 days)/86400, 3e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 8 days)/86400, 6532e12);
            increaseRobiBoost(msg.sender, (block.timestamp - 9 days)/86400, 111113e12);
            increaseRobiBoost(msg.sender, (block.timestamp - 10 days)/86400, 134113e14);
            increaseRobiBoost(msg.sender, (block.timestamp - 11 days)/86400, 3333e14);
            increaseRobiBoost(msg.sender, (block.timestamp - 12 days)/86400, 2222e14);
            increaseRobiBoost(msg.sender, (block.timestamp - 13 days)/86400, 7777e14);
            increaseRobiBoost(msg.sender, (block.timestamp - 14 days)/86400, 5555e14);
            increaseRobiBoost(msg.sender, (block.timestamp - 15 days)/86400, 1000e18);
            increaseRobiBoost(msg.sender, (block.timestamp - 16 days)/86400, 10000e18);

        }
    }

    //External functions --------------------------------------------------------------------------------------------

    function getLevel(uint tokenId) external view returns(uint){
        return _tokens[tokenId].level;
    }

    function getRB(uint tokenId) external view returns(uint){
        return _tokens[tokenId].robiBoost;
    }

    function getInfoForStaking(uint tokenId) external view returns(
        address tokenOwner,
        bool stakeFreeze,
        uint robiBoost
    ){
        tokenOwner = ownerOf(tokenId);
        robiBoost = _tokens[tokenId].robiBoost;
        stakeFreeze = _tokens[tokenId].stakeFreeze;
    }

    function setRBTable(uint[7] calldata rbTable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rbTable = rbTable;
    }

    function setLevelTable(uint[7] calldata levelTable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _levelTable = levelTable;
    }

    function setLevelUpPercent(uint8 percent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(percent > 0, "Wrong percent value");
        _levelUpPercent = percent;
    }

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE){
        _internalBaseURI = newBaseUri;
    }

    function tokenFreeze(uint tokenId) external onlyRole(TOKEN_FREEZER) {
        // Clear all approvals when freeze token
        _approve(address(0), tokenId);

        _tokens[tokenId].stakeFreeze = true;
    }

    function tokenUnfreeze(uint tokenId) external onlyRole(TOKEN_FREEZER) {
        _tokens[tokenId].stakeFreeze = false;
    }

    function accrueRB(address user, uint amount) external onlyRole(RB_SETTER_ROLE) {
        uint curDay = block.timestamp/86400;
        increaseRobiBoost(user, curDay, amount);
        emit RBAccrued(user, _robiBoost[user][curDay]);
    }

    //Public functions --------------------------------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) //TODO Check!!
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns(bool)
    {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function remainRBToNextLevel(uint[] calldata tokenId) public view returns(uint[] memory) {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        uint[] memory remainRB = new uint[](tokenId.length);
        for(uint i = 0; i < tokenId.length; i++){
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            remainRB[i] = _remainRBToMaxLevel(tokenId[i]);
        }
        return remainRB;
    }

    function getRbBalance(address user) public view returns(uint){
        return _getRbBalance(user);
    }

    function getRbBalanceByDays(address user, uint dayCount) public view returns(uint[] memory){
        uint[] memory balance = new uint[](dayCount);
        for(uint i = 0; i < dayCount; i++){
            balance[i] = _robiBoost[user][(block.timestamp - i * 1 days)/86400];
        }
        return balance;
    }

    function getRbTotalAmount(uint period) public view returns(uint amount){
        for(uint i = 0; i <= period; i++){
            amount += _robiBoostTotalAmounts[(block.timestamp - i * 1 days)/86400];
        }
        return amount;
    }

    function getToken(uint _tokenId) public view returns(
        uint tokenId,
        address tokenOwner,
        uint level,
        uint rb,
        bool stakeFreeze,
        uint createTimestamp,
        uint remainToNextLevel,
        string memory uri
    ){
        require(_exists(_tokenId), "ERC721: token does not exist");
        Token memory token = _tokens[_tokenId];
        tokenId = _tokenId;
        tokenOwner = ownerOf(_tokenId);
        level = token.level;
        rb = token.robiBoost;
        stakeFreeze = token.stakeFreeze;
        createTimestamp = token.createTimestamp;
        remainToNextLevel = _remainRBToMaxLevel(_tokenId);
        uri = tokenURI(_tokenId);
    }

    function approve(address to, uint256 tokenId) public override {
        if(_tokens[tokenId].stakeFreeze == true){
            revert("ERC721: Token frozen");
        }
        super.approve(to, tokenId);
    }

    function mint(address to) public onlyRole(TOKEN_MINTER_ROLE) {
        require(to != address(0), "Address can not be zero");
        _lastTokenId +=1;
        uint tokenId = _lastTokenId;
        _safeMint(to, tokenId);

        _tokens[tokenId].robiBoost = _initialRobiBoost;
        _tokens[tokenId].createTimestamp = block.timestamp;
        _tokens[tokenId].level = 1; //start from 1 level
    }

    function launchpadMint(address to, uint level, uint robiBoost) public onlyRole(LAUNCHPAD_TOKEN_MINTER) {
        require(to != address(0), "Address can not be zero");
        require(_rbTable[level] >= robiBoost, "RB Value out of limit");
        _lastTokenId +=1;
        uint tokenId = _lastTokenId;
        _safeMint(to, tokenId);
        _tokens[tokenId].robiBoost = robiBoost;
        _tokens[tokenId].createTimestamp = block.timestamp;
        _tokens[tokenId].level = level;
    }

    function levelUp(uint[] calldata tokenId) public nonReentrant {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        uint currentLevel = _tokens[tokenId[0]].level;
        require(_levelTable[currentLevel] !=0, "This level not upgradable");
        uint numbersOfToken = _levelTable[currentLevel];
        require(numbersOfToken == tokenId.length, "Wrong numbers of tokens received");
        uint neededRb = numbersOfToken * _rbTable[currentLevel];
        uint cumulatedRb = 0;
        for(uint i = 0; i < numbersOfToken; i++){
            Token memory token = _tokens[tokenId[i]]; //safe gas
            require(token.level == currentLevel, "Token not from this level");
            cumulatedRb += token.robiBoost;
        }
        if(neededRb == cumulatedRb){
            _mintLevelUp((currentLevel + 1), tokenId);
        } else{
            revert("Wrong robi boost amount");
        }
        emit LevelUp(msg.sender, (currentLevel + 1), tokenId);
    }

    function sendRBToToken(uint[] calldata tokenId, uint[] calldata amount) public nonReentrant {
        _sendRBToToken(tokenId, amount);
    }

    function sendRBToMaxInTokenLevel(uint[] calldata tokenId) public nonReentrant {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        uint neededAmount;
        uint[] memory amounts = new uint[](tokenId.length);
        for(uint i = 0; i < tokenId.length; i++){
            uint amount = _remainRBToMaxLevel(tokenId[i]);
            amounts[i] = amount;
            neededAmount += amount;
        }
        uint availableAmount = _getRbBalance(msg.sender);
        if(availableAmount >= neededAmount){
            _sendRBToToken(tokenId, amounts);
        } else{
            revert("insufficient funds");
        }
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable) {
        if(_tokens[tokenId].stakeFreeze == true){
            revert("ERC721: Token frozen");
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _getRbBalance(address user) internal view returns(uint balance){
        for(uint i = 0; i <= _burnRBPeriod; i++){
            balance += _robiBoost[user][(block.timestamp - i * 1 days)/86400];
        }
        return balance;
    }

    function _remainRBToMaxLevel(uint tokenId) internal view returns(uint) {
        return _rbTable[uint(_tokens[tokenId].level)] - _tokens[tokenId].robiBoost;
    }

    function _sendRBToToken(uint[] memory tokenId, uint[] memory amount) internal {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        require(tokenId.length == amount.length, "Wrong length of arrays");
        for(uint i = 0; i < tokenId.length; i++){
            require(ownerOf(tokenId[i]) == msg.sender, "Not owner of token");
            uint calcAmount = amount[i];
            uint period = _burnRBPeriod;
            uint currentRB;
            uint curDay;
            while(calcAmount > 0 || period > 0){
                curDay = (block.timestamp - period * 1 days)/86400;
                currentRB = _robiBoost[msg.sender][curDay];
                if(currentRB == 0) {
                    period--;
                    continue;
                }
                if(calcAmount > currentRB){
                    calcAmount -= currentRB;
                    _robiBoostTotalAmounts[curDay] -= currentRB;
                    delete _robiBoost[msg.sender][curDay];

                } else {
                    decreaseRobiBoost(msg.sender, curDay, calcAmount);
                    calcAmount = 0;
                    break;
                }
                period--;
            }
            if(calcAmount == 0){
                _gainRB(tokenId[i], amount[i]);
            } else{
                revert("Not enough RB balance");
            }
        }
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _mintLevelUp(uint level, uint[] memory tokenId) private {
        uint newRobiBoost = 0;
        for(uint i = 0; i <tokenId.length; i++){
            require(ownerOf(tokenId[i]) == msg.sender, "Not owner of token");
            newRobiBoost += _tokens[tokenId[i]].robiBoost;
            _burn(tokenId[i]);
        }
        newRobiBoost = newRobiBoost + newRobiBoost * _levelUpPercent / 100;
        _lastTokenId +=1;
        uint newTokenId = _lastTokenId;
        _safeMint(msg.sender, newTokenId);
        _tokens[newTokenId].robiBoost = newRobiBoost;
        _tokens[newTokenId].createTimestamp = block.timestamp;
        _tokens[newTokenId].level = level;
    }

    function increaseRobiBoost(address user, uint day, uint amount) private {
        _robiBoost[user][day] += amount;
        _robiBoostTotalAmounts[day] += amount;
    }

    function decreaseRobiBoost(address user, uint day, uint amount) private {
        require(_robiBoost[user][day] >= amount && _robiBoostTotalAmounts[day] >= amount, "Wrong amount");
        _robiBoost[user][day] -= amount;
        _robiBoostTotalAmounts[day] -= amount;
    }

    function _gainRB(uint tokenId, uint rb) private {
        require(_exists(tokenId), "Token does not exist");
        require(_tokens[tokenId].stakeFreeze == false, "Token is staked");
        Token storage token = _tokens[tokenId];
        uint newRP = token.robiBoost + rb;
        require(newRP <= _rbTable[token.level], "RB value over limit by level");
        token.robiBoost = newRP;
        emit GainRB(tokenId, newRP);
    }
}