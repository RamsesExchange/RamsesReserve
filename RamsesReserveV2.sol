// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.16;

import "./interfaces/IRamsesV2Factory.sol";
import "./interfaces/IPairFactory.sol";
import "./interfaces/IRamsesV2PoolImmutables.sol";

contract RamsesReserveV2 {
    address public multisig;
    address public rateManager;

    uint256 public constant MAX_BPS_V1 = 500; //Max fee of 500bps = 5%
    uint24 public constant MAX_BPS_V2 = 100_000; // Max fee of 10%

    IPairFactory public factoryV1;
    IRamsesV2Factory public factoryV2;

    event feeChangeV1(address _pair, uint256 _newrate);
    event feeChangeV2(address _pair, uint256 _newrate);
    event newGlobalVolatileFee(uint256 _newBps);
    event newGlobalCorrelatedFee(uint256 _newBps);

    /// @notice Ensures only the Ramses Multisig can interact
    modifier onlyRamsesMultisig() {
        require(
            msg.sender == multisig,
            "only the Ramses multisig can perform this function"
        );
        _;
    }

    /// @notice Only authorized parties (multisig + rateManager)
    modifier onlyAuth() {
        require(
            msg.sender == rateManager || msg.sender == multisig,
            "Only authorized users can call this function"
        );
        _;
    }

    constructor(
        address _pairFactory,
        address _pairFactoryV2
    ) {
        multisig = 0x20D630cF1f5628285BfB91DfaC8C89eB9087BE1A;
        rateManager = msg.sender;
        factoryV1 = IPairFactory(_pairFactory);
        factoryV2 = IRamsesV2Factory(_pairFactoryV2);
    }

    /// @notice accept the candidate position
    function acceptFeeAccess() external onlyRamsesMultisig {
        factoryV1.acceptFeeManager();
    }

    /// @notice ONLY to call if the multisig is moving
    /// @param _newMultisig is the new multisig address
    function changeMultisig(address _newMultisig) external onlyRamsesMultisig {
        multisig = _newMultisig;
    }

    /// @notice Returns the rate manager access for V1 + V2 back to the ramsesMultisig
    function setRateManagerBackToMultisig() external onlyRamsesMultisig {
        factoryV1.setFeeManager(multisig);
        factoryV2.setFeeSetter(multisig);
    }

    /// @notice Sets the RateManager address
    /// @param _rateManager is the new rateManager variable
    function setNewRateManager(
        address _rateManager
    ) external onlyRamsesMultisig {
        rateManager = _rateManager;
    }

    /// @notice changes the Fee of a V1 pair
    /// @param _pair is an array of all the V1 pairs that are to be altered
    /// @param _bps is an array of all the fee variables to adjust the pairs
    function setFeeV1(
        address[] calldata _pair,
        uint256[] calldata _bps
    ) external onlyAuth {
        for (uint256 i = 0; i < _pair.length; ++i) {
            require((_bps[i] > 0) && (_bps[i] <= MAX_BPS_V1), "!valid");
            if (factoryV1.pairFee(_pair[i]) == _bps[i]) continue;
            factoryV1.setPairFee(_pair[i], _bps[i]);
            emit feeChangeV1(_pair[i], _bps[i]);
        }
    }

    /// @notice sets the uint24 fee variable for each V2 pair in the array
    /// @param _pair is an array of all the V2 (CL) pairs that are to be changed
    /// @param _fee is an array of all the fee variables (as uint24) to adjust to
    function setFeeV2(
        address[] calldata _pair,
        uint24[] calldata _fee
    ) external onlyAuth {
        for (uint256 i = 0; i < _pair.length; ++i) {
            require((_fee[i] > 0) && (_fee[i] <= MAX_BPS_V2), "!valid");
            if (IRamsesV2PoolImmutables(_pair[i]).fee() == _fee[i]) continue;
            factoryV2.setFee(_pair[i], _fee[i]);
            emit feeChangeV2(_pair[i], _fee[i]);
        }
    }

    /// @notice Changes the fees of all CorrelatedPairs
    /// @param _bps is the global fee to change the correlated pairs to
    function changeDefaultCorrelated(uint256 _bps) external onlyAuth {
        require(_bps <= MAX_BPS_V1 && _bps > 0);
        factoryV1.setFee(true, _bps);
        emit newGlobalCorrelatedFee(_bps);
    }

    /// @notice Changes the fees of all volatile pairs
    /// @param _bps is the global fee to change the volatile pairs to
    function changeDefaultVolatile(uint256 _bps) external onlyAuth {
        require(_bps <= MAX_BPS_V1 && _bps > 0);
        factoryV1.setFee(false, _bps);
        emit newGlobalVolatileFee(_bps);
    }
}
