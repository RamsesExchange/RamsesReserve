// SPDX-License-Identifier: MIT
/*************************************************************************************
 RamsesReserve BPS altering contract
 Author(s): DOG @RAMSES Exchange on Arbitrum One
 Description: Reserve contract to montior and adjust dynamic fees according to
 market volatility and as outlined in the Ramses official documentation
*************************************************************************************/

pragma solidity ^0.8.16;

interface IPairFactory {
    function acceptFeeManager() external;

    function setFee(bool _stable, uint256 _fee) external;

    function setPairFee(address _pair, uint256 _fee) external;

    function pairFee(address _pair) external view returns (uint256);

    function setFeeManager(address _feeManager) external;
}

contract RamsesReserve {
    address public multisig;
    address private rateManager;
    bool private isPaused;
    uint256 public constant MAX_BPS = 500; //Max fee of 500bps = 5%
    address private pairFactory;
    IPairFactory factory;
    event rateAdjustment(address _pair, uint256 _newrate);
    event allPairAdjustment(bool _stable, uint256 _newBps);

    // Ensures only the Ramses Multisig can interact
    modifier onlyRamsesMultisig() {
        require(msg.sender == multisig, "only the Ramses multisig can perform this function");
        _;
    }

    // Only the Rate manager
    modifier onlyRatesManager() {
        require(msg.sender == rateManager || msg.sender == multisig, "Only authorized RateManagers can call this function");
        _;
    }

    // While the program is not paused (is active)
    modifier whileNotPaused() {
        require(isPaused == false, "The program is paused right now");
        _;
    }

    constructor(
        address _multisig,
        address _initialRateManager,
        address _pairFactory
    ) {
        multisig = _multisig;
        rateManager = _initialRateManager;
        pairFactory = _pairFactory;
        factory = IPairFactory(_pairFactory);
        isPaused = false;
    }

    /**********************************************************************************/
    /**********************************************************************************/
    //**@Multisig Functions**//
    /**********************************************************************************/
    /**********************************************************************************/

    //accept the candidate position
    function acceptFeeAccess() external onlyRamsesMultisig {
        factory.acceptFeeManager();
    }

    //ONLY to call if the multisig is moving verifiably
    function changeMultisig(address _newMultisig) external onlyRamsesMultisig {
        multisig = _newMultisig;
    }

    //Returns the fee management back to the ramsesMultisig
    function setFeeManagerBackToMultisig() external onlyRamsesMultisig {
        factory.setFeeManager(multisig);
    }

    // Sets the RateManager address
    function setNewRateManager(address _RateManager) external onlyRamsesMultisig {
        rateManager = _RateManager;
    }

    // Sets a new pair factory address, for if the contract is moved
    function setNewPairFactory(address _newPairFactory) external onlyRamsesMultisig {
        pairFactory = _newPairFactory;
        factory = IPairFactory(_newPairFactory);
    }

    // Pauses or unpauses the state of the contract/program
    function setPausedState(bool _pausedState) external onlyRamsesMultisig {
        isPaused = _pausedState;
    }

    /**********************************************************************************/
    /**********************************************************************************/
    //**@RateManager Functions**//
    /**********************************************************************************/
    /**********************************************************************************/

    //@Manager Hikes the rate of a pair
    function rateHike(address[] calldata _pair, uint256 _bps) external onlyRatesManager {
        require(_bps <= MAX_BPS, "The bps cannot be over the MAX_BPS");
        for (uint256 i = 0; i < _pair.length; ++i) {
            require(factory.pairFee(_pair[i]) < _bps, "You can only hike upwards");
            factory.setPairFee(_pair[i], _bps);
            emit rateAdjustment(_pair[i], _bps);
        }
    }

    //@Manager Decreases the rate of a pair
    function rateDecrease(address[] calldata _pair, uint256 _bps) external onlyRatesManager whileNotPaused {
        require(_bps > 0, "The bps cannot be 0");
        for (uint256 i = 0; i < _pair.length; ++i) {
            require(factory.pairFee(_pair[i]) > _bps, "You can only decrease downwards");
            factory.setPairFee(_pair[i], _bps);
            emit rateAdjustment(_pair[i], _bps);
        }
    }

    //@Manager Changes the fees of all CorrelatedPairs
    function changeAllCorrelatedFees(uint256 _bps) external onlyRatesManager whileNotPaused {
        require(_bps <= MAX_BPS && _bps > 0);
        factory.setFee(true, _bps);
        emit allPairAdjustment(true, _bps);
    }

    //@Manager Changes the fees of all volatile pairs
    function changeAllVolatileFees(uint256 _bps) external onlyRatesManager whileNotPaused {
        require(_bps <= MAX_BPS && _bps > 0);
        factory.setFee(false, _bps);
        emit allPairAdjustment(false, _bps);
    }

    /**********************************************************************************/
    /**********************************************************************************/
    //**@Public Functions**//
    /**********************************************************************************/
    /**********************************************************************************/
    function getRatesManager() external view returns (address) {
        return rateManager;
    }

    function getPairFactory() external view returns (address) {
        return pairFactory;
    }
}
