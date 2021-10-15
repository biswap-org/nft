// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.4;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface ISwapFeeRewardWithRB {
    function accrueRBFromMarket(address account, address fromToken, uint amount) external;
}

interface ISmartChefMarket {
    function updateStakedTokens(address _user, uint amount) external;
}

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//BSW, BNB, WBNB, BUSD, USDT
contract Market is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    enum Side {Sell, Buy}
    enum OfferStatus {Open, Accepted, Cancelled}

    uint constant MAX_DEFAULT_FEE = 1000; // max fee 10%
    uint public defaultFee = 100; //in base 10000 1%
    uint8 public maxUserTokenOnSellToReward;
    uint rewardDistributionSeller = 50; //Distribution reward between seller and buyer. Base 100
    address public treasuryAddress;
    address public WBNBAddress;
    ISwapFeeRewardWithRB accruerRB;
    ISmartChefMarket smartChefMarket;
    bool RBAccrueIsEnabled;
    bool placementRewardEnabled; //Enable rewards for place NFT tokens on market


    Offer[] public offers;
    mapping(IERC721 => mapping(uint256 => uint256)) public tokenSellOffers; // nft => tokenId => id
    mapping(address => mapping(IERC721 => mapping(uint256 => uint256))) public userBuyOffers; // user => nft => tokenId => id
    mapping(IERC721 => bool) public nftWhitelist;
    mapping(address => bool) public dealTokensWhitelist;
    mapping(address => uint) public userFee; //User trade fee. if Zero - fee by default
    mapping(address => uint) public tokensCount; //User`s number of tokens on sale: user => count

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
    event NFTWhiteListUpdate(IERC721 nft, bool whiteListed);
    event DealTokensWhiteListUpdate(address token, bool whiteListed);
    event NewUserFee(address user, uint fee);

    constructor(
        address _treasuryAddress,
        address _WBNBAddress, //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
        address _USDT,
        address _BSW,
        ISwapFeeRewardWithRB _accruerRB
    ) {
        treasuryAddress = _treasuryAddress;
        WBNBAddress = _WBNBAddress;
        accruerRB = _accruerRB;
        RBAccrueIsEnabled = true;
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

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function enableRBAccrue() public onlyOwner {
        RBAccrueIsEnabled = true;
    }

    function disableRBAccrue() public onlyOwner {
        RBAccrueIsEnabled = false;
    }

    function enablePlacementReward() public onlyOwner {
        placementRewardEnabled = true;
    }

    function disablePlacementReward() public onlyOwner {
        placementRewardEnabled = false;
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        treasuryAddress = _treasuryAddress;
        emit NewTreasuryAddress(_treasuryAddress);
    }

    function setRewardDistributionSeller(uint _rewardDistributionSeller) public onlyOwner {
        require(_rewardDistributionSeller <= 100, "Incorrect value Must be equal to or greater than 100");
        rewardDistributionSeller = _rewardDistributionSeller;
    }

    function addWhiteListNFT(IERC721[] calldata nfts) public onlyOwner {
        for (uint256 i = 0; i < nfts.length; i++) {
            nftWhitelist[nfts[i]] = true;
            emit NFTWhiteListUpdate(nfts[i], true);
        }
    }

    function delWhiteListNFT(IERC721[] calldata nfts) public onlyOwner {
        for (uint256 i = 0; i < nfts.length; i++) {
            delete nftWhitelist[nfts[i]];
            emit NFTWhiteListUpdate(nfts[i], false);
        }
    }

    function addWhiteListDealTokens(address[] calldata _tokens) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            dealTokensWhitelist[_tokens[i]] = true;
            emit DealTokensWhiteListUpdate(_tokens[i], true);
        }
    }

    function delWhiteListDealTokens(address[] calldata _tokens) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            delete dealTokensWhitelist[_tokens[i]];
            emit DealTokensWhiteListUpdate(_tokens[i], false);
        }
    }

    function setUserFee(address user, uint fee) public onlyOwner {
        userFee[user] = fee;
        emit NewUserFee(user, fee);
    }

    function setDefaultFee(uint _newFee) public onlyOwner {
        require(_newFee <= MAX_DEFAULT_FEE, "New fee must be less than or equal to max fee");
        defaultFee = _newFee;
    }

    function SetMaxUserTokenOnSellToReward(uint8 newCount) public onlyOwner {
        maxUserTokenOnSellToReward = newCount;
    }

    function setSmartChefMarket(ISmartChefMarket _smartChefMarket) public onlyOwner {
        smartChefMarket = _smartChefMarket;
    }

    // user functions

    function offer(
        Side side,
        address dealToken,
        IERC721 nft,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant whenNotPaused _nftAllowed(nft) _validDealToken(dealToken) {
        if (side == Side.Buy) {
            _offerBuy(nft, tokenId,  price, dealToken);
        } else if (side == Side.Sell) {
            _offerSell(nft, tokenId, price, dealToken);
        } else {
            revert('Not supported');
        }
    }

    function accept(uint256 id)
        public
        payable
        nonReentrant
        _offerExists(id)
        _offerOpen(id)
        _notWhiteListed(id)
        whenNotPaused
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

    function multiCancel(uint256[] calldata ids) public {
        for (uint256 i = 0; i < ids.length; i++) {
            cancel(ids[i]);
        }
    }

    //increase: true - increase token to accrue rewards; false - decrease token from
    function placementRewardQualifier(bool increase, address user) internal {
        if (placementRewardEnabled == false) return;

        if(increase){
            tokensCount[user]++;
        } else {
            tokensCount[user] = tokensCount[user] > 0 ? tokensCount[user] -= 1 : 0;
        }
        if(tokensCount[user] > maxUserTokenOnSellToReward) return;

        uint stakedAmount = tokensCount[user] >= maxUserTokenOnSellToReward ? maxUserTokenOnSellToReward : tokensCount[user];
        smartChefMarket.updateStakedTokens(user, stakedAmount);
    }

    function _offerSell(
        IERC721 nft,
        uint256 tokenId,
        uint256 price,
        address dealToken
    ) internal {
        require(msg.value == 0, 'Seller should not pay');
        require(price > 0, 'price > 0');
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
        emit NewOffer(msg.sender, nft, tokenId, dealToken, price, Side.Sell, id);

        require(getTokenOwner(id) == msg.sender, 'sender should own the token');
        require(isTokenApproved(id, msg.sender), 'token is not approved');

        if(tokenSellOffers[nft][tokenId] > 0){
            _closeSellOfferFor(nft, tokenId);
        } else {
            placementRewardQualifier(true, msg.sender);
        }
        tokenSellOffers[nft][tokenId] = id;

    }

    function _offerBuy(IERC721 nft, uint256 tokenId,uint price, address dealToken) internal {
        if(msg.value > 0){
            price = msg.value;
            dealToken = WBNBAddress;
            IWETH(WBNBAddress).deposit{value: msg.value}();
        } else {
            IERC20(dealToken).safeTransferFrom(msg.sender, address(this), price);
        }
        require(price > 0, 'buyer should pay');
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
        require(msg.value == 0, 'Seller should not pay');

        require(getTokenOwner(id) == msg.sender, 'only owner can call');
        require(isTokenApproved(id, msg.sender), 'token is not approved');
        _offer.status = OfferStatus.Accepted;
        _offer.acceptUser = msg.sender;

        _offer.nft.safeTransferFrom(msg.sender, _offer.user, _offer.tokenId);
        _distributePayment(_offer);

        emit AcceptOffer(id, msg.sender, _offer.price);
        _unlinkBuyOffer(_offer);
        if(tokenSellOffers[_offer.nft][_offer.tokenId] > 0){
            _closeSellOfferFor(_offer.nft, _offer.tokenId);
            placementRewardQualifier(true, msg.sender);
        }
    }

    function _acceptSell(uint256 id) internal {
        // caller is buyer
        Offer storage _offer = offers[id];

        if(getTokenOwner(id) != _offer.user || isTokenApproved(id, _offer.user) == false){
            _cancelSell(id);
            return;
        }

        _offer.status = OfferStatus.Accepted;
        _offer.acceptUser = msg.sender;
        _unlinkSellOffer(_offer);
        //If deal token is WBNB we can receive and convert BNB to WBNB
        if(address(_offer.dealToken) == WBNBAddress && msg.value >= _offer.price){
            _offer.price = msg.value;
            IWETH(WBNBAddress).deposit{value: msg.value}();
        } else {
            _offer.dealToken.safeTransferFrom(msg.sender, address(this), _offer.price);
        }
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
        require(id > 0 && id < offers.length, 'offer does not exist');
        _;
    }

    modifier _offerOpen(uint256 id) {
        require(offers[id].status == OfferStatus.Open, 'offer should be open');
        _;
    }

    modifier _offerOwner(uint256 id) {
        require(offers[id].user == msg.sender, 'call should own the offer');
        _;
    }

    modifier _notWhiteListed(uint256 id) {
        Offer storage _offer = offers[id];
        require(nftWhitelist[_offer.nft], 'NFT not in white list');
        _;
    }

    modifier _nftAllowed(IERC721 nft) {
        require(nftWhitelist[nft], 'NFT not in white list');
        _;
    }

    // internal functions
    function _transfer(address to, uint256 amount, IERC20 _dealToken) internal {
        if (amount > 0) {
            _dealToken.safeTransfer(to, amount);
        }
    }

    function _distributePayment(Offer memory _offer) internal {
        address seller = _offer.side == Side.Sell? _offer.user : _offer.acceptUser;
        address buyer = _offer.side == Side.Buy? _offer.user : _offer.acceptUser;
        uint256 feeRate = userFee[seller] == 0 ? defaultFee : userFee[seller];
        uint256 fee = (_offer.price * feeRate) / 10000;
        _transfer(treasuryAddress, fee, _offer.dealToken);
        _transfer(seller, _offer.price - fee, _offer.dealToken);
        if(RBAccrueIsEnabled){
            accruerRB.accrueRBFromMarket(seller, address(_offer.dealToken), fee * rewardDistributionSeller / 100);
            accruerRB.accrueRBFromMarket(buyer, address(_offer.dealToken), fee * (100 - rewardDistributionSeller) / 100);
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
        if (id > 0 && _offer.status == OfferStatus.Open && _offer.side == Side.Buy) {
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
        placementRewardQualifier(false, o.user);
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

    function isTokenApproved(uint256 id, address owner) public view returns (bool) {
        Offer storage _offer = offers[id];
        return
        _offer.nft.getApproved(_offer.tokenId) == address(this) ||
        _offer.nft.isApprovedForAll(owner, address(this));
    }

    function getTokenOwner(uint256 id) public view returns (address) {
        Offer storage _offer = offers[id];
        return _offer.nft.ownerOf(_offer.tokenId);
    }
}