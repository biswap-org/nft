//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @notice Biswap NFT interface
 */
interface IBiswapNFT {
    function launchpadMint(
        address to,
        uint256 level,
        uint256 robiBoost
    ) external;
}

/**
 * @notice Competition awarding contract. Award in NTF
 */
contract CompetitionRewardNFT is ReentrancyGuard, Ownable, Pausable {

    IBiswapNFT biswapNFT;


    /**
     * @notice Constructor
     * @param _biswapNFT: BiswapNFT contract
     */
    constructor(IBiswapNFT _biswapNFT) {
        biswapNFT = _biswapNFT;
    }
}
