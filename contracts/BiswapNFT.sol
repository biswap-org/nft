//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract BiswapNFT is Initializable, ERC721EnumerableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant TOKEN_FREEZER = keccak256("TOKEN_FREEZER");
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER");
    bytes32 public constant LAUNCHPAD_TOKEN_MINTER = keccak256("LAUNCHPAD_TOKEN_MINTER");
    bytes32 public constant RB_SETTER_ROLE = keccak256("RB_SETTER");
    uint256 public constant MAX_ARRAY_LENGTH_PER_REQUEST = 30;

    string private _internalBaseURI;
    uint256 private _initialRobiBoost;
    uint256 private _burnRBPeriod; //in days
    uint8 private _levelUpPercent; //in percents
    uint256[7] private _rbTable;
    uint256[7] private _levelTable;
    uint256 private _lastTokenId;

    struct Token {
        uint256 robiBoost;
        uint256 level;
        bool stakeFreeze; //Lock a token when it is staked
        uint256 createTimestamp;
    }

    mapping(uint256 => Token) private _tokens;
    mapping(address => mapping(uint256 => uint256)) private _robiBoost;
    mapping(uint256 => uint256) private _robiBoostTotalAmounts;

    event GainRB(uint256 indexed tokenId, uint256 newRB);
    event RBAccrued(address user, uint256 amount);
    event LevelUp(address indexed user, uint256 indexed newLevel, uint256[] parentsTokensId);
    //BNF-01, SFR-01
    event Initialize(string baseURI, uint256 initialRobiBoost, uint256 burnRBPeriod);
    event TokenMint(address indexed to, uint256 indexed tokenId, uint256 level, uint256 robiBoost);

    function initialize(
        string memory baseURI,
        uint256 initialRobiBoost,
        uint256 burnRBPeriod
    ) public initializer {
        __ERC721_init("BiswapRobbiesEarn", "BRE");
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

        //BNF-01, SFR-01
        emit Initialize(baseURI, initialRobiBoost, burnRBPeriod);
    }

    //External functions --------------------------------------------------------------------------------------------

    function getLevel(uint256 tokenId) external view returns (uint256) {
        return _tokens[tokenId].level;
    }

    function getRB(uint256 tokenId) external view returns (uint256) {
        return _tokens[tokenId].robiBoost;
    }

    function getInfoForStaking(uint256 tokenId)
        external
        view
        returns (
            address tokenOwner,
            bool stakeFreeze,
            uint256 robiBoost
        )
    {
        tokenOwner = ownerOf(tokenId);
        robiBoost = _tokens[tokenId].robiBoost;
        stakeFreeze = _tokens[tokenId].stakeFreeze;
    }

    function setRBTable(uint256[7] calldata rbTable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rbTable = rbTable;
    }

    function setLevelTable(uint256[7] calldata levelTable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _levelTable = levelTable;
    }

    function setLevelUpPercent(uint8 percent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(percent > 0, "Wrong percent value");
        _levelUpPercent = percent;
    }

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _internalBaseURI = newBaseUri;
    }

    function setBurnRBPeriod(uint256 newPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newPeriod > 0, "Wrong period");
        _burnRBPeriod = newPeriod;
    }

    function tokenFreeze(uint256 tokenId) external onlyRole(TOKEN_FREEZER) {
        // Clear all approvals when freeze token
        _approve(address(0), tokenId);

        _tokens[tokenId].stakeFreeze = true;
    }

    function tokenUnfreeze(uint256 tokenId) external onlyRole(TOKEN_FREEZER) {
        _tokens[tokenId].stakeFreeze = false;
    }

    function accrueRB(address user, uint256 amount) external onlyRole(RB_SETTER_ROLE) {
        uint256 curDay = block.timestamp / 86400;
        increaseRobiBoost(user, curDay, amount);
        emit RBAccrued(user, _robiBoost[user][curDay]);
    }

    //Public functions --------------------------------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function remainRBToNextLevel(uint256[] calldata tokenId) public view returns (uint256[] memory) {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        uint256[] memory remainRB = new uint256[](tokenId.length);
        for (uint256 i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            remainRB[i] = _remainRBToMaxLevel(tokenId[i]);
        }
        return remainRB;
    }

    function getRbBalance(address user) public view returns (uint256) {
        return _getRbBalance(user);
    }

    function getRbBalanceByDays(address user, uint256 dayCount) public view returns (uint256[] memory) {
        uint256[] memory balance = new uint256[](dayCount);
        for (uint256 i = 0; i < dayCount; i++) {
            balance[i] = _robiBoost[user][(block.timestamp - i * 1 days) / 86400];
        }
        return balance;
    }

    function getRbTotalAmount(uint256 period) public view returns (uint256 amount) {
        for (uint256 i = 0; i <= period; i++) {
            amount += _robiBoostTotalAmounts[(block.timestamp - i * 1 days) / 86400];
        }
        return amount;
    }

    function getToken(uint256 _tokenId)
        public
        view
        returns (
            uint256 tokenId,
            address tokenOwner,
            uint256 level,
            uint256 rb,
            bool stakeFreeze,
            uint256 createTimestamp,
            uint256 remainToNextLevel,
            string memory uri
        )
    {
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
        if (_tokens[tokenId].stakeFreeze == true) {
            revert("ERC721: Token frozen");
        }
        super.approve(to, tokenId);
    }

    //BNF-02, SCN-01, SFR-02
    function mint(address to) public onlyRole(TOKEN_MINTER_ROLE) nonReentrant {
        require(to != address(0), "Address can not be zero");
        _lastTokenId += 1;
        uint256 tokenId = _lastTokenId;
        _tokens[tokenId].robiBoost = _initialRobiBoost;
        _tokens[tokenId].createTimestamp = block.timestamp;
        _tokens[tokenId].level = 1; //start from 1 level
        _safeMint(to, tokenId);
    }

    //BNF-02, SCN-01, SFR-02
    function launchpadMint(
        address to,
        uint256 level,
        uint256 robiBoost
    ) public onlyRole(LAUNCHPAD_TOKEN_MINTER) nonReentrant {
        require(to != address(0), "Address can not be zero");
        require(_rbTable[level] >= robiBoost, "RB Value out of limit");
        _lastTokenId += 1;
        uint256 tokenId = _lastTokenId;
        _tokens[tokenId].robiBoost = robiBoost;
        _tokens[tokenId].createTimestamp = block.timestamp;
        _tokens[tokenId].level = level;
        _safeMint(to, tokenId);
    }

    function levelUp(uint256[] calldata tokenId) public nonReentrant {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        uint256 currentLevel = _tokens[tokenId[0]].level;
        require(_levelTable[currentLevel] != 0, "This level not upgradable");
        uint256 numbersOfToken = _levelTable[currentLevel];
        require(numbersOfToken == tokenId.length, "Wrong numbers of tokens received");
        uint256 neededRb = numbersOfToken * _rbTable[currentLevel];
        uint256 cumulatedRb = 0;
        for (uint256 i = 0; i < numbersOfToken; i++) {
            Token memory token = _tokens[tokenId[i]]; //safe gas
            require(token.level == currentLevel, "Token not from this level");
            cumulatedRb += token.robiBoost;
        }
        if (neededRb == cumulatedRb) {
            _mintLevelUp((currentLevel + 1), tokenId);
        } else {
            revert("Wrong robi boost amount");
        }
        emit LevelUp(msg.sender, (currentLevel + 1), tokenId);
    }

    function sendRBToToken(uint256[] calldata tokenId, uint256[] calldata amount) public nonReentrant {
        _sendRBToToken(tokenId, amount);
    }

    function sendRBToMaxInTokenLevel(uint256[] calldata tokenId) public nonReentrant {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        uint256 neededAmount;
        uint256[] memory amounts = new uint256[](tokenId.length);
        for (uint256 i = 0; i < tokenId.length; i++) {
            uint256 amount = _remainRBToMaxLevel(tokenId[i]);
            amounts[i] = amount;
            neededAmount += amount;
        }
        uint256 availableAmount = _getRbBalance(msg.sender);
        if (availableAmount >= neededAmount) {
            _sendRBToToken(tokenId, amounts);
        } else {
            revert("insufficient funds");
        }
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }

    function _safeMint(address to, uint256 tokenId) internal override {
        super._safeMint(to, tokenId);
        emit TokenMint(to, tokenId, _tokens[tokenId].level, _tokens[tokenId].robiBoost);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable) {
        if (_tokens[tokenId].stakeFreeze == true) {
            revert("ERC721: Token frozen");
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _getRbBalance(address user) internal view returns (uint256 balance) {
        for (uint256 i = 0; i <= _burnRBPeriod; i++) {
            balance += _robiBoost[user][(block.timestamp - i * 1 days) / 86400];
        }
        return balance;
    }

    function _remainRBToMaxLevel(uint256 tokenId) internal view returns (uint256) {
        return _rbTable[uint256(_tokens[tokenId].level)] - _tokens[tokenId].robiBoost;
    }

    function _sendRBToToken(uint256[] memory tokenId, uint256[] memory amount) internal {
        require(tokenId.length <= MAX_ARRAY_LENGTH_PER_REQUEST, "Array length gt max");
        require(tokenId.length == amount.length, "Wrong length of arrays");
        for (uint256 i = 0; i < tokenId.length; i++) {
            require(ownerOf(tokenId[i]) == msg.sender, "Not owner of token");
            uint256 calcAmount = amount[i];
            uint256 period = _burnRBPeriod;
            uint256 currentRB;
            uint256 curDay;
            while (calcAmount > 0 || period > 0) {
                curDay = (block.timestamp - period * 1 days) / 86400;
                currentRB = _robiBoost[msg.sender][curDay];
                if (currentRB == 0) {
                    period--;
                    continue;
                }
                if (calcAmount > currentRB) {
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
            if (calcAmount == 0) {
                _gainRB(tokenId[i], amount[i]);
            } else {
                revert("Not enough RB balance");
            }
        }
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _mintLevelUp(uint256 level, uint256[] memory tokenId) private {
        uint256 newRobiBoost = 0;
        for (uint256 i = 0; i < tokenId.length; i++) {
            require(ownerOf(tokenId[i]) == msg.sender, "Not owner of token");
            newRobiBoost += _tokens[tokenId[i]].robiBoost;
            _burn(tokenId[i]);
        }
        newRobiBoost = newRobiBoost + (newRobiBoost * _levelUpPercent) / 100;
        _lastTokenId += 1;
        uint256 newTokenId = _lastTokenId;
        _tokens[newTokenId].robiBoost = newRobiBoost;
        _tokens[newTokenId].createTimestamp = block.timestamp;
        _tokens[newTokenId].level = level;
        _safeMint(msg.sender, newTokenId);
    }

    function increaseRobiBoost(
        address user,
        uint256 day,
        uint256 amount
    ) private {
        _robiBoost[user][day] += amount;
        _robiBoostTotalAmounts[day] += amount;
    }

    function decreaseRobiBoost(
        address user,
        uint256 day,
        uint256 amount
    ) private {
        require(_robiBoost[user][day] >= amount && _robiBoostTotalAmounts[day] >= amount, "Wrong amount");
        _robiBoost[user][day] -= amount;
        _robiBoostTotalAmounts[day] -= amount;
    }

    function _gainRB(uint256 tokenId, uint256 rb) private {
        require(_exists(tokenId), "Token does not exist");
        require(_tokens[tokenId].stakeFreeze == false, "Token is staked");
        Token storage token = _tokens[tokenId];
        uint256 newRP = token.robiBoost + rb;
        require(newRP <= _rbTable[token.level], "RB value over limit by level");
        token.robiBoost = newRP;
        emit GainRB(tokenId, newRP);
    }
}
