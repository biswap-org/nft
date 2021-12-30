//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

interface ISquidPlayerNFT {
    // function squidEnergyDecrease(uint[] calldata tokenId, uint[] calldata deduction) external;
    function squidEnergyIncrease(uint[] calldata tokenId, uint128[] calldata addition, address user) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IBiswapNFT {
    function getRbBalance(address user) external view returns(uint);
    function exchangeRB(uint amount, address userAddress) external;
    function getRbBalanceByDays(address user, uint dayCount) external view returns(uint[] memory);

}

contract RBToSEExchange is Ownable, Pausable, ReentrancyGuard{
    IBiswapNFT public biswapNFT;
    ISquidPlayerNFT public squidPlayerNFT;
    uint public exchangeRate;
    uint public burnRBPeriod;
    uint public divisor;

    event ExchangeRateUpdated(uint newExchangeRate, uint newDivisor);
    event TokensAddressUpdated(address sitswapNFT, address squidPlayerNFT);
    event TokensSwapped(uint[] playerNFTIds, uint128[] seAmounts, uint RBAmount); //SEAmount 1RB = SE[]
    
    constructor(
        IBiswapNFT _biswapNFT,
        ISquidPlayerNFT _squidPlayerNFT,
        uint _burnRBPeriod,
        uint _newExchangeRate,
        uint _divisor
    ){
        updateTokensAddress(_biswapNFT, _squidPlayerNFT);
        updateExchangeRate(_newExchangeRate, _divisor, _burnRBPeriod);
        pause();
    }

    //Public functions
    function swap(uint[] calldata _playerNFTIds, uint128[] calldata _seAmounts) public whenNotPaused nonReentrant{
        require(_playerNFTIds.length > 0, "RBToSEExchange:: playerNFT array is empty");
        require(_seAmounts.length == _playerNFTIds.length, "RBToSEExchange:: RB array has different length than playerNFTIds array!");

        uint availableRBAmount = biswapNFT.getRbBalance(msg.sender);
        uint requireRBAmount = 0;
        for(uint i = 0; i < _seAmounts.length; i++){
            requireRBAmount += _seAmounts[i];
        }
        requireRBAmount = requireRBAmount * divisor  / exchangeRate;

        require(requireRBAmount <= availableRBAmount, "RBToSEExchange:: Insufficient RB balance");
        biswapNFT.exchangeRB(requireRBAmount, msg.sender);
        squidPlayerNFT.squidEnergyIncrease(_playerNFTIds, _seAmounts, msg.sender);
        emit TokensSwapped(_playerNFTIds, _seAmounts, requireRBAmount);
    }

    function getUserInfo(address user) public view returns(uint rbBalance, uint seBalance, uint[] memory rbBalancesByDay){
        uint period = burnRBPeriod;
        rbBalance = biswapNFT.getRbBalance(user);
        seBalance = rbBalance * exchangeRate  / divisor;
        rbBalancesByDay = new uint[](period);
        rbBalancesByDay = biswapNFT.getRbBalanceByDays(user, period);
    }

    //Ownable functions
    function updateExchangeRate(uint _newExchangeRate, uint _divisor, uint _burnRBPeriod) public onlyOwner{
        require(_newExchangeRate > 0, "RBToSEExchange:: Exchange rate cant be 0!");
        require(_burnRBPeriod > 0, "Burn RB period must be greater than 0");
        require(_divisor > 0, "RBToSEExchange:: Divisor cant be 0!");

        divisor = _divisor;
        exchangeRate = _newExchangeRate;
        burnRBPeriod = _burnRBPeriod;
        emit ExchangeRateUpdated(exchangeRate, _divisor);
    }

    function updateTokensAddress(IBiswapNFT _biswapNFT, ISquidPlayerNFT _squidPlayerNFT) public onlyOwner{
        require(address(_biswapNFT) != address(0) && address(_squidPlayerNFT) != address(0), "RBToSEExchange:: NFT address empty!");
        biswapNFT = _biswapNFT;
        squidPlayerNFT = _squidPlayerNFT;
        emit TokensAddressUpdated(address(_biswapNFT), address(_squidPlayerNFT));
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}