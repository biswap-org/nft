// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ISwapFeeRewardWithRB {
    function accrueRBFromAuction(
        address account,
        address fromToken,
        uint256 amount
    ) external;
}

contract Auction is ReentrancyGuard, Ownable, Pausable, IERC721Receiver {
    using SafeERC20 for IERC20;

    enum State {
        ST_OPEN,
        ST_FINISHED,
        ST_CANCELLED
    }

    struct TokenPair {
        IERC721 nft;
        uint256 tokenId;
    }

    struct Inventory {
        TokenPair pair;
        address seller;
        address bidder;
        IERC20 currency;
        uint256 askPrice;
        uint256 bidPrice;
        uint256 netBidPrice;
        uint256 startBlock;
        uint256 endTimestamp;
        State status;
    }

    struct RoyaltyStr {
        uint32 rate;
        address receiver;
        bool enable;
    }

    event NFTBlacklisted(IERC721 nft, bool whitelisted);
    event NewAuction(
        uint256 indexed id,
        address indexed seller,
        IERC20 currency,
        uint256 askPrice,
        uint256 endTimestamp,
        TokenPair pair
    );
    event NewBid(
        uint256 indexed id,
        address indexed bidder,
        uint256 price,
        uint256 netPrice,
        uint256 endTimestamp
    );
    event AuctionCancelled(uint256 indexed id);
    event AuctionFinished(uint256 indexed id, address indexed winner);
    event NFTAccrualListUpdate(address nft, bool state);
    event SetRoyalty(
        address nftAddress,
        address royaltyReceiver,
        uint32 rate,
        bool enable
    );

    bool internal _canReceive = false;
    Inventory[] public auctions;
    //    mapping(uint256 => mapping(uint256 => TokenPair)) public auctionNfts; delete

    mapping(IERC721 => bool) public nftBlacklist;
    mapping(address => bool) public nftForAccrualRB; //add tokens on which RobiBoost is accrual
    mapping(IERC20 => bool) public dealTokensWhitelist;
    mapping(IERC721 => mapping(uint256 => uint256)) public auctionNftIndex; // nft -> tokenId -> id
    mapping(address => uint256) public userFee; //User auction fee. if Zero - default fee
    mapping(address => RoyaltyStr) public royalty; //Royalty for NFT creator. NFTToken => royalty (base 10000)


    uint256 constant MAX_DEFAULT_FEE = 1000; // max fee 10%
    address public treasuryAddress;
    uint256 public defaultFee = 100; //in base 10000 1%

    uint256 public extendEndTimestamp; // in seconds
    uint256 public minAuctionDuration; // in seconds
    uint256 public prolongationTime; // in seconds


    uint256 public rateBase;
    uint256 public bidderIncentiveRate;
    uint256 public bidIncrRate;
    ISwapFeeRewardWithRB feeRewardRB;
    bool public feeRewardRBIsEnabled = true;

    constructor(
        uint256 extendEndTimestamp_,
        uint256 prolongationTime_,
        uint256 minAuctionDuration_,
        uint256 rateBase_,
        uint256 bidderIncentiveRate_,
        uint256 bidIncrRate_,
        address treasuryAddress_,
        ISwapFeeRewardWithRB feeRewardRB_
    ) {
        extendEndTimestamp = extendEndTimestamp_;
        prolongationTime = prolongationTime_;
        minAuctionDuration = minAuctionDuration_;
        rateBase = rateBase_;
        bidderIncentiveRate = bidderIncentiveRate_;
        bidIncrRate = bidIncrRate_;
        treasuryAddress = treasuryAddress_;
        feeRewardRB = feeRewardRB_;

        auctions.push(
            Inventory({
                pair: TokenPair(IERC721(address(0)), 0),
                seller: address(0),
                bidder: address(0),
                currency: IERC20(address(0)),
                askPrice: 0,
                bidPrice: 0,
                netBidPrice: 0,
                startBlock: 0,
                endTimestamp: 0,
                status: State.ST_CANCELLED
            })
        );
    }

    function updateSettings(
        uint256 extendEndTimestamp_,
        uint256 prolongationTime_,
        uint256 minAuctionDuration_,
        uint256 rateBase_,
        uint256 bidderIncentiveRate_,
        uint256 bidIncrRate_,
        address treasuryAddress_,
        ISwapFeeRewardWithRB _feeRewardRB
    ) public onlyOwner {
        prolongationTime = prolongationTime_;
        extendEndTimestamp = extendEndTimestamp_;
        minAuctionDuration = minAuctionDuration_;
        rateBase = rateBase_;
        bidderIncentiveRate = bidderIncentiveRate_;
        bidIncrRate = bidIncrRate_;
        treasuryAddress = treasuryAddress_;
        feeRewardRB = _feeRewardRB;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function addWhiteListDealTokens(IERC20[] calldata _tokens)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(address(_tokens[i]) != address(0), "Address cant be 0");
            dealTokensWhitelist[_tokens[i]] = true;
        }
    }

    function delWhiteListDealTokens(IERC20[] calldata _tokens)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _tokens.length; i++) {
            delete dealTokensWhitelist[_tokens[i]];
        }
    }

    function blacklistNFT(IERC721 nft) public onlyOwner {
        nftBlacklist[nft] = true;
        emit NFTBlacklisted(nft, true);
    }

    function unblacklistNFT(IERC721 nft) public onlyOwner {
        delete nftBlacklist[nft];
        emit NFTBlacklisted(nft, false);
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
    }

    function setDefaultFee(uint256 _newFee) public onlyOwner {
        require(
            _newFee <= MAX_DEFAULT_FEE,
            "New fee must be less than or equal to max fee"
        );
        defaultFee = _newFee;
    }

    function enableRBFeeReward() public onlyOwner {
        feeRewardRBIsEnabled = true;
    }

    function disableRBFeeReward() public onlyOwner {
        feeRewardRBIsEnabled = false;
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

    // public

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override whenNotPaused returns (bytes4) {
        if (data.length > 0) {
            require(operator == from, "caller should own the token");
            require(!nftBlacklist[IERC721(msg.sender)], "token not allowed");
            (IERC20 currency, uint256 askPrice, uint256 endTimestamp) = abi
                .decode(data, (IERC20, uint256, uint256));
            TokenPair memory pair = TokenPair({
                nft: IERC721(msg.sender),
                tokenId: tokenId
            });
            _sell(from, pair, currency, askPrice, endTimestamp);
        } else {
            require(_canReceive, "cannot transfer directly");
        }

        return this.onERC721Received.selector;
    }

    function sell(
        TokenPair calldata pair,
        IERC20 currency,
        uint256 askPrice,
        uint256 endTimestamp
    ) public nonReentrant whenNotPaused _waitForTransfer notContract {
        require(address(pair.nft) != address(0), "Address cant be zero");

        require(!nftBlacklist[pair.nft], "token not allowed");
        require(
            _isTokenOwnerAndApproved(pair.nft, pair.tokenId),
            "token not approved"
        );
        pair.nft.safeTransferFrom(msg.sender, address(this), pair.tokenId);

        _sell(msg.sender, pair, currency, askPrice, endTimestamp);
    }

    function _sell(
        address seller,
        TokenPair memory pair,
        IERC20 currency,
        uint256 askPrice,
        uint256 endTimestamp
    ) internal _allowedDealToken(currency) {
        require(askPrice > 0, "askPrice > 0");
        require(
            endTimestamp >= block.timestamp + minAuctionDuration,
            "auction duration not long enough"
        );

        uint256 id = auctions.length;

        auctions.push(
            Inventory({
                pair: pair,
                seller: seller,
                bidder: address(0),
                currency: currency,
                askPrice: askPrice,
                bidPrice: 0,
                netBidPrice: 0,
                startBlock: block.number,
                endTimestamp: endTimestamp,
                status: State.ST_OPEN
            })
        );

        auctionNftIndex[pair.nft][pair.tokenId] = id;
        emit NewAuction(id, seller, currency, askPrice, endTimestamp, pair);
    }

    function bid(uint256 id, uint256 offer)
        public
        _hasAuction(id)
        _isStOpen(id)
        nonReentrant
        whenNotPaused
        notContract
    {
        Inventory storage inv = auctions[id];
        require(block.timestamp < inv.endTimestamp, "auction finished");

        // minimum increment
        require(offer >= getMinBidPrice(id), "offer not enough");

        inv.currency.safeTransferFrom(msg.sender, address(this), offer);

        // transfer some to previous bidder
        uint256 incentive = 0;
        if (inv.netBidPrice > 0 && inv.bidder != address(0)) {
            incentive = (offer * bidderIncentiveRate) / rateBase;
            _transfer(inv.currency, inv.bidder, inv.netBidPrice + incentive);
        }

        inv.bidPrice = offer;
        inv.netBidPrice = offer - incentive;
        inv.bidder = msg.sender;
        if (block.timestamp + extendEndTimestamp >= inv.endTimestamp) {
            inv.endTimestamp += prolongationTime;
        }

        emit NewBid(id, msg.sender, offer, inv.netBidPrice, inv.endTimestamp);
    }

    function cancel(uint256 id)
        public
        _hasAuction(id)
        _isStOpen(id)
        _isSeller(id)
        nonReentrant
        whenNotPaused
        notContract
    {
        Inventory storage inv = auctions[id];
        require(inv.bidder == address(0), "has bidder");
        _cancel(id);
    }

    function _cancel(uint256 id) internal {
        Inventory storage inv = auctions[id];

        inv.status = State.ST_CANCELLED;
        _transferInventoryTo(id, inv.seller);
        delete auctionNftIndex[inv.pair.nft][inv.pair.tokenId];
        emit AuctionCancelled(id);
    }

    // anyone can collect any auction, as long as it's finished
    function collect(uint256[] calldata ids) public nonReentrant whenNotPaused {
        for (uint256 i = 0; i < ids.length; i++) {
            _collectOrCancel(ids[i]);
        }
    }

    function _collectOrCancel(uint256 id)
        internal
        _hasAuction(id)
        _isStOpen(id)
    {
        Inventory storage inv = auctions[id];
        require(block.timestamp >= inv.endTimestamp, "auction not done yet");
        if (inv.bidder == address(0)) {
            _cancel(id);
        } else {
            _collect(id);
        }
    }

    function _collect(uint256 id) internal {
        Inventory storage inv = auctions[id];

        // take fee
        uint256 feeRate = userFee[inv.seller] == 0
            ? defaultFee
            : userFee[inv.seller];
        uint256 fee = (inv.netBidPrice * feeRate) / 10000;

        if (fee > 0) {
            _transfer(inv.currency, treasuryAddress, fee);
            if (
                feeRewardRBIsEnabled && nftForAccrualRB[address(inv.pair.nft)]
            ) {
                feeRewardRB.accrueRBFromAuction(
                    inv.bidder,
                    address(inv.currency),
                    fee / 2
                );
                feeRewardRB.accrueRBFromAuction(
                    inv.seller,
                    address(inv.currency),
                    fee / 2
                );
            }
        }
        uint256 royaltyFee = 0;
        if(royalty[address(inv.pair.nft)].enable){
            royaltyFee = (inv.netBidPrice * royalty[address(inv.pair.nft)].rate) / 10000;
            _transfer(inv.currency, royalty[address(inv.pair.nft)].receiver, royaltyFee);
        }

        // transfer profit and token
        _transfer(inv.currency, inv.seller, inv.netBidPrice - fee - royaltyFee);
        inv.status = State.ST_FINISHED;
        _transferInventoryTo(id, inv.bidder);

        emit AuctionFinished(id, inv.bidder);
    }

    function isOpen(uint256 id) public view _hasAuction(id) returns (bool) {
        Inventory storage inv = auctions[id];
        return
            inv.status == State.ST_OPEN && block.timestamp < inv.endTimestamp;
    }

    function isCollectible(uint256 id)
        public
        view
        _hasAuction(id)
        returns (bool)
    {
        Inventory storage inv = auctions[id];
        return
            inv.status == State.ST_OPEN && block.timestamp >= inv.endTimestamp;
    }

    function isCancellable(uint256 id)
        public
        view
        _hasAuction(id)
        returns (bool)
    {
        Inventory storage inv = auctions[id];
        return inv.status == State.ST_OPEN && inv.bidder == address(0);
    }

    function numAuctions() public view returns (uint256) {
        return auctions.length;
    }

    function getMinBidPrice(uint256 id) public view returns (uint256) {
        Inventory storage inv = auctions[id];

        // minimum increment
        if (inv.bidPrice == 0) {
            return inv.askPrice;
        } else {
            return inv.bidPrice + (inv.bidPrice * bidIncrRate) / rateBase;
        }
    }

    // internal

    modifier _isStOpen(uint256 id) {
        require(
            auctions[id].status == State.ST_OPEN,
            "auction finished or cancelled"
        );
        _;
    }

    modifier _hasAuction(uint256 id) {
        require(id > 0 && id < auctions.length, "auction does not exist");
        _;
    }

    modifier _isSeller(uint256 id) {
        require(auctions[id].seller == msg.sender, "caller is not seller");
        _;
    }

    modifier _allowedDealToken(IERC20 token) {
        require(dealTokensWhitelist[token], "currency not allowed");
        _;
    }

    modifier _waitForTransfer() {
        _canReceive = true;
        _;
        _canReceive = false;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    function _transfer(
        IERC20 currency,
        address to,
        uint256 amount
    ) internal {
        require(amount > 0 && to != address(0), "Wrong amount or dest address");
        currency.safeTransfer(to, amount);
    }

    function _isTokenOwnerAndApproved(IERC721 token, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        return
            (token.ownerOf(tokenId) == msg.sender) &&
            (token.getApproved(tokenId) == address(this) ||
                token.isApprovedForAll(msg.sender, address(this)));
    }

    function _transferInventoryTo(uint256 id, address to) internal {
        Inventory storage inv = auctions[id];
        inv.pair.nft.safeTransferFrom(address(this), to, inv.pair.tokenId);
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
