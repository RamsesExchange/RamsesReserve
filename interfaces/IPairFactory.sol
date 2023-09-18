// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPairFactory {
    function setFeeManager(address _feeManager) external;

    function acceptFeeManager() external;

    function setFee(bool _stable, uint256 _fee) external;

    function setPairFee(address _pair, uint256 _fee) external;

    function getFee(bool _stable) external view returns (uint256);

    function isPair(address pair) external view returns (bool);

    function pairCodeHash() external view returns (bytes32);

    function allPairsLength() external view returns (uint256);

    function getPair(
        address tokenA,
        address token,
        bool stable
    ) external view returns (address);

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);

    function voter() external view returns (address);

    function pairFee(address _pair) external view returns (uint256);
}
