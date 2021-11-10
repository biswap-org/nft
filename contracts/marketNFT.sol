// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface ISwapFeeRewardWithRB {
    function accrueRBFromMarket(
        address account,
        address fromToken,
        uint256 amount
    ) external;
}

interface ISmartChefMarket {
    function updateStakedTokens(address _user, uint256 amount) external;
}

//BSW, BNB, WBNB, BUSD, USDT
contract Market is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    enum Side {
        Sell,
        Buy
    }
    enum OfferStatus {
        Open,
        Accepted,
        Cancelled
    }

    struct RoyaltyStr {
        uint32 rate;
        address receiver;
        bool enable;
    }

    uint256 constant MAX_DEFAULT_FEE = 1000; // max fee 10% (base 10000)
    uint256 public defaultFee = 100; //in base 10000 1%
    uint8 public maxUserTokenOnSellToReward = 3; //max count sell offers of nftForAccrualRB on which Rb accrual
    uint256 rewardDistributionSeller = 50; //Distribution reward between seller and buyer. Base 100
    address public treasuryAddress;
    address public immutable WBNBAddress;
    ISwapFeeRewardWithRB feeRewardRB;
    ISmartChefMarket smartChefMarket;
    bool feeRewardRBIsEnabled; // Enable/disable accrue RB reward for trade NFT tokens from nftForAccrualRB list
    bool placementRewardEnabled; //Enable rewards for place NFT tokens on market

    Offer[] public offers;
    mapping(IERC721 => mapping(uint256 => uint256)) public tokenSellOffers; // nft => tokenId => id
    mapping(address => mapping(IERC721 => mapping(uint256 => uint256))) public userBuyOffers; // user => nft => tokenId => id
    mapping(address => bool) public nftBlacklist; //add tokens on blackList
    mapping(address => bool) public nftForAccrualRB; //add tokens on which RobiBoost is accrual
    mapping(address => bool) public dealTokensWhitelist;
    mapping(address => uint256) public userFee; //User trade fee. if Zero - fee by default
    mapping(address => uint256) public tokensCount; //User`s number of tokens on sale: user => count
    mapping(address => RoyaltyStr) public royalty; //Royalty for NFT creator. NFTToken => royalty (base 10000)

    struct Offer {
        uint256 tokenId;
        uint256 price;
        IERC20 dealToken;
        IERC721 nft;
        address user;
        address acceptUser;
        OfferStatus status;
        Side side;
    }

    event NewOffer(
        address indexed user,
        IERC721 indexed nft,
        uint256 indexed tokenId,
        address dealToken,
        uint256 price,
        Side side,
        uint256 id
    );

    event CancelOffer(uint256 indexed id);
    event AcceptOffer(uint256 indexed id, address indexed user, uint256 price);
    event NewTreasuryAddress(address _treasuryAddress);
    event NFTBlackListUpdate(address nft, bool state);
    event NFTAccrualListUpdate(address nft, bool state);
    event DealTokensWhiteListUpdate(address token, bool whiteListed);
    event NewUserFee(address user, uint256 fee);
    event SetRoyalty(
        address nftAddress,
        address royaltyReceiver,
        uint32 rate,
        bool enable
    );

    constructor(
        address _treasuryAddress,
        address _WBNBAddress, //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
        address _USDT,
        address _BSW,
        ISwapFeeRewardWithRB _feeRewardRB
    ) {
        //NFT-01
        require(_treasuryAddress != address(0), "Address cant be zero");
        require(_WBNBAddress != address(0), "Address cant be zero");
        require(_USDT != address(0), "Address cant be zero");
        require(_BSW != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
        WBNBAddress = _WBNBAddress;
        feeRewardRB = _feeRewardRB;
        feeRewardRBIsEnabled = true;
        // take id(0) as placeholder
        offers.push(
            Offer({
                tokenId: 0,
                price: 0,
                nft: IERC721(address(0)),
                dealToken: IERC20(address(0)),
                user: address(0),
                acceptUser: address(0),
                status: OfferStatus.Cancelled,
                side: Side.Buy
            })
        );
        dealTokensWhitelist[_USDT] = true;
        dealTokensWhitelist[_BSW] = true;
        dealTokensWhitelist[_WBNBAddress] = true;
    }

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function enableRBFeeReward() public onlyOwner {
        feeRewardRBIsEnabled = true;
    }

    function disableRBFeeReward() public onlyOwner {
        feeRewardRBIsEnabled = false;
    }

    function enablePlacementReward() public onlyOwner {
        placementRewardEnabled = true;
    }

    function disablePlacementReward() public onlyOwner {
        placementRewardEnabled = false;
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        //NFT-01
        require(_treasuryAddress != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
        emit NewTreasuryAddress(_treasuryAddress);
    }

    function setRewardDistributionSeller(uint256 _rewardDistributionSeller)
        public
        onlyOwner
    {
        require(
            _rewardDistributionSeller <= 100,
            "Incorrect value Must be equal to or greater than 100"
        );
        rewardDistributionSeller = _rewardDistributionSeller;
    }

    function setRoyalty(
        address nftAddress,
        address royaltyReceiver,
        uint32 rate,
        bool enable
    ) public onlyOwner {
        require(nftAddress != address(0), "Address cant be zero");
        require(royaltyReceiver != address(0), "Address cant be zero");
        require(rate < 10000, "Rate must be less than 10000");
        royalty[nftAddress].receiver = royaltyReceiver;
        royalty[nftAddress].rate = rate;
        royalty[nftAddress].enable = enable;
        emit SetRoyalty(nftAddress, royaltyReceiver, rate, enable);
    }

    function addBlackListNFT(address[] calldata nfts) public onlyOwner {
        for (uint256 i = 0; i < nfts.length; i++) {
            nftBlacklist[nfts[i]] = true;
            emit NFTBlackListUpdate(nfts[i], true);
        }
    }

    function delBlackListNFT(address[] calldata nfts) public onlyOwner {
        for (uint256 i = 0; i < nfts.length; i++) {
            delete nftBlacklist[nfts[i]];
            emit NFTBlackListUpdate(nfts[i], false);
        }
    }

    function addWhiteListDealTokens(address[] calldata _tokens)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0), "Address cant be 0");
            dealTokensWhitelist[_tokens[i]] = true;
            emit DealTokensWhiteListUpdate(_tokens[i], true);
        }
    }

    function delWhiteListDealTokens(address[] calldata _tokens)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _tokens.length; i++) {
            delete dealTokensWhitelist[_tokens[i]];
            emit DealTokensWhiteListUpdate(_tokens[i], false);
        }
    }

    function addNftForAccrualRB(address _nft) public onlyOwner {
        require(_nft != address(0), "Address cant be zero");
        nftForAccrualRB[_nft] = true;
        emit NFTAccrualListUpdate(_nft, true);
    }

    function delNftForAccrualRB(address _nft) public onlyOwner {
        require(_nft != address(0), "Address cant be zero");
        delete nftForAccrualRB[_nft];
        emit NFTAccrualListUpdate(_nft, false);
    }

    function setUserFee(address user, uint256 fee) public onlyOwner {
        userFee[user] = fee;
        emit NewUserFee(user, fee);
    }

    function setDefaultFee(uint256 _newFee) public onlyOwner {
        require(
            _newFee <= MAX_DEFAULT_FEE,
            "New fee must be less than or equal to max fee"
        );
        defaultFee = _newFee;
    }

    function SetMaxUserTokenOnSellToReward(uint8 newCount) public onlyOwner {
        maxUserTokenOnSellToReward = newCount;
    }

    function setSmartChefMarket(ISmartChefMarket _smartChefMarket)
        public
        onlyOwner
    {
        require(address(_smartChefMarket) != address(0), "Address cant be 0");
        smartChefMarket = _smartChefMarket;
    }

    function setFeeRewardRB(ISwapFeeRewardWithRB _feeRewardRB)
        public
        onlyOwner
    {
        require(address(_feeRewardRB) != address(0), "Address cant be 0");
        feeRewardRB = _feeRewardRB;
    }

    // user functions

    function offer(
        Side side,
        address dealToken,
        IERC721 nft,
        uint256 tokenId,
        uint256 price
    )
        public
        payable
        nonReentrant
        whenNotPaused
        _nftAllowed(nft)
        _validDealToken(dealToken)
        notContract
    {
        if (side == Side.Buy) {
            _offerBuy(nft, tokenId, price, dealToken);
        } else if (side == Side.Sell) {
            _offerSell(nft, tokenId, price, dealToken);
        } else {
            revert("Not supported");
        }
    }

    function accept(uint256 id)
        public
        payable
        nonReentrant
        _offerExists(id)
        _offerOpen(id)
        _notBlackListed(id)
        whenNotPaused
        notContract
    {
        if (offers[id].side == Side.Buy) {
            _acceptBuy(id);
        } else {
            _acceptSell(id);
        }
    }

    function cancel(uint256 id)
        public
        nonReentrant
        _offerExists(id)
        _offerOpen(id)
        _offerOwner(id)
        whenNotPaused
    {
        if (offers[id].side == Side.Buy) {
            _cancelBuy(id);
        } else {
            _cancelSell(id);
        }
    }

    function multiCancel(uint256[] calldata ids) public notContract {
        for (uint256 i = 0; i < ids.length; i++) {
            cancel(ids[i]);
        }
    }

    //increase: true - increase token to accrue rewards; false - decrease token from
    function placementRewardQualifier(
        bool increase,
        address user,
        address nftToken
    ) internal {
        //Check if nft token in nftForAccrualRB list and accrue reward enable
        if (!nftForAccrualRB[nftToken] || !placementRewardEnabled) return;

        if (increase) {
            tokensCount[user]++;
        } else {
            tokensCount[user] = tokensCount[user] > 0
                ? tokensCount[user] - 1
                : 0;
        }
        if (tokensCount[user] > maxUserTokenOnSellToReward) return;

        uint256 stakedAmount = tokensCount[user] >= maxUserTokenOnSellToReward
            ? maxUserTokenOnSellToReward
            : tokensCount[user];
        smartChefMarket.updateStakedTokens(user, stakedAmount);
    }

    function _offerSell(
        IERC721 nft,
        uint256 tokenId,
        uint256 price,
        address dealToken
    ) internal {
        require(msg.value == 0, "Seller should not pay");
        require(price > 0, "price > 0");
        offers.push(
            Offer({
                tokenId: tokenId,
                price: price,
                dealToken: IERC20(dealToken),
                nft: nft,
                user: msg.sender,
                acceptUser: address(0),
                status: OfferStatus.Open,
                side: Side.Sell
            })
        );

        uint256 id = offers.length - 1;
        emit NewOffer(
            msg.sender,
            nft,
            tokenId,
            dealToken,
            price,
            Side.Sell,
            id
        );

        require(getTokenOwner(id) == msg.sender, "sender should own the token");
        require(isTokenApproved(id, msg.sender), "token is not approved");

        if (tokenSellOffers[nft][tokenId] > 0) {
            _closeSellOfferFor(nft, tokenId);
        } else {
            placementRewardQualifier(true, msg.sender, address(nft));
        }
        tokenSellOffers[nft][tokenId] = id;
    }

    function _offerBuy(
        IERC721 nft,
        uint256 tokenId,
        uint256 price,
        address dealToken
    ) internal {
        IERC20(dealToken).safeTransferFrom(msg.sender, address(this), price);
        require(price > 0, "buyer should pay");
        offers.push(
            Offer({
                tokenId: tokenId,
                price: price,
                dealToken: IERC20(dealToken),
                nft: nft,
                user: msg.sender,
                acceptUser: address(0),
                status: OfferStatus.Open,
                side: Side.Buy
            })
        );
        uint256 id = offers.length - 1;
        emit NewOffer(msg.sender, nft, tokenId, dealToken, price, Side.Buy, id);
        _closeUserBuyOffer(userBuyOffers[msg.sender][nft][tokenId]);
        userBuyOffers[msg.sender][nft][tokenId] = id;
    }

    function _acceptBuy(uint256 id) internal {
        // caller is seller
        Offer storage _offer = offers[id];
        require(msg.value == 0, "seller should not pay");

        require(getTokenOwner(id) == msg.sender, "only owner can call");
        require(isTokenApproved(id, msg.sender), "token is not approved");
        _offer.status = OfferStatus.Accepted;
        _offer.acceptUser = msg.sender;

        _offer.nft.safeTransferFrom(msg.sender, _offer.user, _offer.tokenId);
        _distributePayment(_offer);

        emit AcceptOffer(id, msg.sender, _offer.price);
        _unlinkBuyOffer(_offer);
        if (tokenSellOffers[_offer.nft][_offer.tokenId] > 0) {
            _closeSellOfferFor(_offer.nft, _offer.tokenId);
            //NFT-03
            placementRewardQualifier(false, msg.sender, address(_offer.nft));
        }
    }

    function _acceptSell(uint256 id) internal {
        // caller is buyer
        Offer storage _offer = offers[id];

        if (
            getTokenOwner(id) != _offer.user ||
            isTokenApproved(id, _offer.user) == false
        ) {
            _cancelSell(id);
            return;
        }

        _offer.status = OfferStatus.Accepted;
        _offer.acceptUser = msg.sender;
        _unlinkSellOffer(_offer);

        _offer.dealToken.safeTransferFrom(msg.sender, address(this), _offer.price);
        _distributePayment(_offer);
        _offer.nft.safeTransferFrom(_offer.user, msg.sender, _offer.tokenId);
        emit AcceptOffer(id, msg.sender, _offer.price);
    }

    function _cancelSell(uint256 id) internal {
        Offer storage _offer = offers[id];
        require(_offer.status == OfferStatus.Open, "Offer was cancelled");
        _offer.status = OfferStatus.Cancelled;
        emit CancelOffer(id);
        _unlinkSellOffer(_offer);
    }

    function _cancelBuy(uint256 id) internal {
        Offer storage _offer = offers[id];
        require(_offer.status == OfferStatus.Open, "Offer was cancelled");
        _offer.status = OfferStatus.Cancelled;
        _transfer(msg.sender, _offer.price, _offer.dealToken);
        emit CancelOffer(id);
        _unlinkBuyOffer(_offer);
    }

    // modifiers
    modifier _validDealToken(address _token) {
        require(dealTokensWhitelist[_token], "Deal token not available");
        _;
    }
    modifier _offerExists(uint256 id) {
        require(id > 0 && id < offers.length, "offer does not exist");
        _;
    }

    modifier _offerOpen(uint256 id) {
        require(offers[id].status == OfferStatus.Open, "offer should be open");
        _;
    }

    modifier _offerOwner(uint256 id) {
        require(offers[id].user == msg.sender, "call should own the offer");
        _;
    }

    modifier _notBlackListed(uint256 id) {
        Offer storage _offer = offers[id];
        require(!nftBlacklist[address(_offer.nft)], "NFT in black list");
        _;
    }

    modifier _nftAllowed(IERC721 nft) {
        require(!nftBlacklist[address(nft)], "NFT in black list");
        _;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    // internal functions
    function _transfer(
        address to,
        uint256 amount,
        IERC20 _dealToken
    ) internal {
        require(amount > 0 && to != address(0), "Wrong amount or dest on transfer");
        _dealToken.safeTransfer(to, amount);
    }

    function _distributePayment(Offer memory _offer) internal {
        (address seller, address buyer) = _offer.side == Side.Sell
            ? (_offer.user, _offer.acceptUser)
            : (_offer.acceptUser, _offer.user);
        uint256 feeRate = userFee[seller] == 0 ? defaultFee : userFee[seller];
        uint256 fee = (_offer.price * feeRate) / 10000;
        uint256 royaltyFee = 0;
        if (royalty[address(_offer.nft)].enable) {
            royaltyFee =
                (_offer.price * royalty[address(_offer.nft)].rate) /
                10000;
            _transfer(
                royalty[address(_offer.nft)].receiver,
                royaltyFee,
                _offer.dealToken
            );
        }
        _transfer(treasuryAddress, fee, _offer.dealToken);
        _transfer(seller, _offer.price - fee - royaltyFee, _offer.dealToken);
        if (feeRewardRBIsEnabled) {
            feeRewardRB.accrueRBFromMarket(
                seller,
                address(_offer.dealToken),
                (fee * rewardDistributionSeller) / 100
            );
            feeRewardRB.accrueRBFromMarket(
                buyer,
                address(_offer.dealToken),
                (fee * (100 - rewardDistributionSeller)) / 100
            );
        }
    }

    function _closeSellOfferFor(IERC721 nft, uint256 tokenId) internal {
        uint256 id = tokenSellOffers[nft][tokenId];
        if (id == 0) return;

        // closes old open sell offer
        Offer storage _offer = offers[id];
        _offer.status = OfferStatus.Cancelled;
        tokenSellOffers[_offer.nft][_offer.tokenId] = 0;
        emit CancelOffer(id);
    }

    function _closeUserBuyOffer(uint256 id) internal {
        Offer storage _offer = offers[id];
        if (
            id > 0 &&
            _offer.status == OfferStatus.Open &&
            _offer.side == Side.Buy
        ) {
            _offer.status = OfferStatus.Cancelled;
            _transfer(_offer.user, _offer.price, _offer.dealToken);
            _unlinkBuyOffer(_offer);
            emit CancelOffer(id);
        }
    }

    function _unlinkBuyOffer(Offer storage o) internal {
        userBuyOffers[o.user][o.nft][o.tokenId] = 0;
    }

    function _unlinkSellOffer(Offer storage o) internal {
        placementRewardQualifier(false, o.user, address(o.nft));
        tokenSellOffers[o.nft][o.tokenId] = 0;
    }

    // helpers

    function isValidSell(uint256 id) public view returns (bool) {
        if (id >= offers.length) {
            return false;
        }

        Offer storage _offer = offers[id];
        // try to not throw exception
        return
            _offer.status == OfferStatus.Open &&
            _offer.side == Side.Sell &&
            isTokenApproved(id, _offer.user) &&
            (_offer.nft.ownerOf(_offer.tokenId) == _offer.user);
    }

    function isTokenApproved(uint256 id, address owner)
        public
        view
        returns (bool)
    {
        Offer storage _offer = offers[id];
        return
            _offer.nft.getApproved(_offer.tokenId) == address(this) ||
            _offer.nft.isApprovedForAll(owner, address(this));
    }

    function getTokenOwner(uint256 id) public view returns (address) {
        Offer storage _offer = offers[id];
        return _offer.nft.ownerOf(_offer.tokenId);
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
