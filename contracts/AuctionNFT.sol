// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface ISwapFeeRewardWithRB {
    function accrueRBFromAuction(address account, address fromToken, uint amount) external;
}


contract Auction is ReentrancyGuard, Ownable, Pausable, IERC721Receiver {
    using SafeERC20 for IERC20;

    enum State {ST_OPEN, ST_FINISHED, ST_CANCELLED}

    struct TokenPair {
        IERC721 nft;
        uint256 tokenId;
    }

    struct Inventory {
        uint256 nftCount;
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

    event NFTWhitelisted(IERC721 nft, bool whitelisted);
    event NewAuction(
        uint256 indexed id,
        address indexed seller,
        IERC20 currency,
        uint256 askPrice,
        uint256 endTimestamp,
        TokenPair[] bundle
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



    bool internal _canReceive = false;
    IWETH public immutable weth;
    Inventory[] public auctions;
    mapping(uint256 => mapping(uint256 => TokenPair)) public auctionNfts;

    mapping(IERC721 => bool) public nftWhitelist;
    mapping(IERC20 => bool) public dealTokenWhitelist;
    mapping(IERC721 => mapping(uint256 => uint256)) public auctionNftIndex; // nft -> tokenId -> id
    mapping(address => uint) public userFee; //User auction fee. if Zero - default fee

    uint constant MAX_DEFAULT_FEE = 1000; // max fee 10%
    address public treasuryAddress;
    uint public defaultFee = 100; //in base 10000 1%


    uint256 public extendEndTimestamp; // in seconds
    uint256 public minAuctionDuration; // in seconds

    uint256 public rateBase;
    uint256 public bidderIncentiveRate;
    uint256 public bidIncrRate;
    ISwapFeeRewardWithRB feeRewardRB;
    bool feeRewardRBIsEnabled;

    constructor(
        IWETH weth_,
        uint256 extendEndTimestamp_,
        uint256 minAuctionDuration_,
        uint256 rateBase_,
        uint256 bidderIncentiveRate_,
        uint256 bidIncrRate_,
        address treasuryAddress_,
        ISwapFeeRewardWithRB feeRewardRB_
    ) {
        weth = weth_;
        extendEndTimestamp = extendEndTimestamp_;
        minAuctionDuration = minAuctionDuration_;
        rateBase = rateBase_;
        bidderIncentiveRate = bidderIncentiveRate_;
        bidIncrRate = bidIncrRate_;
        treasuryAddress = treasuryAddress_;
        feeRewardRB = feeRewardRB_;

        auctions.push(
            Inventory({
        nftCount: 0,
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
        uint256 minAuctionDuration_,
        uint256 rateBase_,
        uint256 bidderIncentiveRate_,
        uint256 bidIncrRate_,
        address treasuryAddress_,
        ISwapFeeRewardWithRB _feeRewardRB
    ) public onlyOwner {
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

    function addWhiteListDealToken(IERC20 cur) public onlyOwner {
        dealTokenWhitelist[cur] = true;
    }

    function unWhitelistDealToken(IERC20 cur) public onlyOwner {
        delete dealTokenWhitelist[cur];
    }

    function whitelistNFT(IERC721 nft) public onlyOwner {
        nftWhitelist[nft] = true;
        emit NFTWhitelisted(nft, true);
    }

    function unwhitelistNFT(IERC721 nft) public onlyOwner {
        delete nftWhitelist[nft];
        emit NFTWhitelisted(nft, false);
    }

    function setUserFee(address user, uint fee) public onlyOwner {
        userFee[user] = fee;
    }

    function setDefaultFee(uint _newFee) public onlyOwner {
        require(_newFee <= MAX_DEFAULT_FEE, "New fee must be less than or equal to max fee");
        defaultFee = _newFee;
    }

    function enableRBFeeReward() public onlyOwner {
        feeRewardRBIsEnabled = true;
    }

    function disableRBFeeReward() public onlyOwner {
        feeRewardRBIsEnabled = false;
    }

    // public

    receive() external payable {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override whenNotPaused returns (bytes4) {
        if (data.length > 0) {
            require(operator == from, 'caller should own the token');
            require(nftWhitelist[IERC721(msg.sender)], 'token not allowed');
            (IERC20 currency, uint256 askPrice, uint256 endTimestamp) = abi.decode(
                data,
                (IERC20, uint256, uint256)
            );
            TokenPair[] memory bundle = new TokenPair[](1);
            bundle[0].nft = IERC721(msg.sender);
            bundle[0].tokenId = tokenId;
            _sell(from, bundle, currency, askPrice, endTimestamp);
        } else {
            require(_canReceive, 'cannot transfer directly');
        }

        return this.onERC721Received.selector;
    }

    function sell(
        TokenPair[] calldata bundle,
        IERC20 currency,
        uint256 askPrice,
        uint256 endTimestamp
    ) public nonReentrant whenNotPaused _waitForTransfer notContract {
        require(bundle.length > 0, 'empty tokens');

        for (uint256 i = 0; i < bundle.length; i++) {
            TokenPair calldata p = bundle[i];
            require(nftWhitelist[p.nft], 'token not allowed');
            require(_isTokenOwnerAndApproved(p.nft, p.tokenId), 'token not approved');
            p.nft.safeTransferFrom(msg.sender, address(this), p.tokenId);
        }

        _sell(msg.sender, bundle, currency, askPrice, endTimestamp);
    }

    function _sell(
        address seller,
        TokenPair[] memory bundle,
        IERC20 currency,
        uint256 askPrice,
        uint256 endTimestamp
    ) internal _allowedDealToken(currency) {
        require(askPrice > 0, 'askPrice > 0');
        require(
            endTimestamp >= block.timestamp + minAuctionDuration,
            'auction duration not long enough'
        );

        uint256 id = auctions.length;
        for (uint256 i = 0; i < bundle.length; i++) {
            auctionNfts[id][i] = bundle[i];
        }

        auctions.push(
            Inventory({
        nftCount: bundle.length,
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

        emit NewAuction(id, seller, currency, askPrice, endTimestamp, bundle);
        _linkNFTToAuction(id);
    }

    function bid(uint256 id, uint256 offer)
    public
    payable
    _hasAuction(id)
    _isStOpen(id)
    nonReentrant
    whenNotPaused
    notContract
    {
        Inventory storage inv = auctions[id];
        require(block.timestamp < inv.endTimestamp, 'auction finished');

        // set offer to native value
        if (address(inv.currency) == address(weth)) {
            offer = msg.value;
        }

        // minimum increment
        require(offer >= getMinBidPrice(id), 'not enough');

        // collect token
        if (address(inv.currency) == address(weth)) {
            weth.deposit{value: offer}(); // convert to weth for later use
        } else {
            inv.currency.safeTransferFrom(msg.sender, address(this), offer);
        }

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
            inv.endTimestamp += extendEndTimestamp;
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
        require(inv.bidder == address(0), 'has bidder');
        _cancel(id);
    }

    function _cancel(uint256 id) internal {
        Inventory storage inv = auctions[id];

        inv.status = State.ST_CANCELLED;
        _transferInventoryTo(id, inv.seller);
        _unlinkNFTToAuction(id);
        emit AuctionCancelled(id);
    }

    // anyone can collect any auction, as long as it's finished
    function collect(uint256[] calldata ids) public nonReentrant whenNotPaused {
        for (uint256 i = 0; i < ids.length; i++) {
            _collectOrCancel(ids[i]);
        }
    }

    function _collectOrCancel(uint256 id) internal _hasAuction(id) _isStOpen(id) {
        Inventory storage inv = auctions[id];
        require(block.timestamp >= inv.endTimestamp, 'auction not done yet');
        if (inv.bidder == address(0)) {
            _cancel(id);
        } else {
            _collect(id);
        }
    }

    function _collect(uint256 id) internal {
        Inventory storage inv = auctions[id];

        // take fee
        uint256 feeRate = userFee[inv.seller] == 0 ? defaultFee : userFee[inv.seller];
        uint256 fee = (inv.netBidPrice * feeRate) / 10000;
        if (fee > 0) {
            _transfer(inv.currency, treasuryAddress, fee);
            if(feeRewardRBIsEnabled){
                feeRewardRB.accrueRBFromAuction(inv.bidder, address(inv.currency), fee / 2);
                feeRewardRB.accrueRBFromAuction(inv.seller, address(inv.currency), fee / 2);
            }
        }

        // transfer profit and token
        _transfer(inv.currency, inv.seller, inv.netBidPrice - fee);
        inv.status = State.ST_FINISHED;
        _transferInventoryTo(id, inv.bidder);
        _unlinkNFTToAuction(id);

        emit AuctionFinished(id, inv.bidder);
    }

    function isOpen(uint256 id) public view _hasAuction(id) returns (bool) {
        Inventory storage inv = auctions[id];
        return inv.status == State.ST_OPEN && block.timestamp < inv.endTimestamp;
    }

    function isCollectible(uint256 id) public view _hasAuction(id) returns (bool) {
        Inventory storage inv = auctions[id];
        return inv.status == State.ST_OPEN && block.timestamp >= inv.endTimestamp;
    }

    function isCancellable(uint256 id) public view _hasAuction(id) returns (bool) {
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
        require(auctions[id].status == State.ST_OPEN, 'auction finished or cancelled');
        _;
    }

    modifier _hasAuction(uint256 id) {
        require(id > 0 && id < auctions.length, 'auction does not exist');
        _;
    }

    modifier _isSeller(uint256 id) {
        require(auctions[id].seller == msg.sender, 'caller is not seller');
        _;
    }

    modifier _allowedDealToken(IERC20 token) {
        require(dealTokenWhitelist[token], 'currency not allowed');
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
        if (amount > 0 && to != address(0)) {
            if (address(currency) == address(weth)) {
                weth.withdraw(amount);
                payable(to).transfer(amount);
            } else {
                currency.safeTransfer(to, amount);
            }
        }
    }

    function _isTokenOwnerAndApproved(IERC721 token, uint256 tokenId) internal view returns (bool) {
        return
        (token.ownerOf(tokenId) == msg.sender) &&
        (token.getApproved(tokenId) == address(this) ||
        token.isApprovedForAll(msg.sender, address(this)));
    }

    function _transferInventoryTo(uint256 id, address to) internal {
        Inventory storage inv = auctions[id];
        for (uint256 i = 0; i < inv.nftCount; i++) {
            TokenPair storage p = auctionNfts[id][i];
            p.nft.safeTransferFrom(address(this), to, p.tokenId);
        }
    }

    function _linkNFTToAuction(uint256 id) internal {
        Inventory storage inv = auctions[id];
        for (uint256 i = 0; i < inv.nftCount; i++) {
            TokenPair storage p = auctionNfts[id][i];
            auctionNftIndex[p.nft][p.tokenId] = id;
        }
    }

    function _unlinkNFTToAuction(uint256 id) internal {
        Inventory storage inv = auctions[id];
        for (uint256 i = 0; i < inv.nftCount; i++) {
            TokenPair storage p = auctionNfts[id][i];
            delete auctionNftIndex[p.nft][p.tokenId];
        }
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}