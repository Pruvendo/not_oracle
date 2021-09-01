/* solhint-disable */
pragma ton-solidity >= 0.45.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../Interfaces.sol";
import "../libraries/Errors.sol";
import "Depoolable.sol";

contract Validator is Depoolable, IValidator {

    // EVENTS
    event RevealPlz(uint256 hashedQuotation);
    // TODO implement TopUpMePlz

    // STATUS
    uint128 public stakeSize;

    // AUTH DATA
    address public elector;

    // ELECTION CYCLE PARAMS
    uint public validationStartTime;
    uint public validationDuration;

    // COSTS
    uint128 constant SIGN_UP_COST = 0.6 ton;
    uint128 constant SET_QUOTATION_COST = 0.6 ton;
    uint128 constant REVEAL_QUOTATION_COST = 0.6 ton;

    // METHODS
    constructor(
        address electorArg,
        uint validationStartTimeArg,
        uint validationDurationArg,
        mapping (address => bool) depoolsArg,
        address ownerArg
    ) public {
        require(tvm.pubkey() != 0, Errors.NO_PUB_KEY);
        require(tvm.pubkey() == msg.pubkey(), Errors.WRONG_PUB_KEY);
        require(validationStartTimeArg > now, Errors.WRONG_MOMENT);
        tvm.accept();
        elector = electorArg;
        validationStartTime = validationStartTimeArg;
        validationDuration = validationDurationArg;
        init(depoolsArg, ownerArg);
    }

    // ELECTION PHASE
    function signUp() override external CheckMsgPubkey {
        require(activeDepool != address(0), Errors.HAS_NO_STAKE);
        tvm.accept();
        IElector(elector).signUp{value: SIGN_UP_COST}(
            amountDeposited,
            validationStartTime,
            validationDuration
        );
    }

    // VALIDATION PHASE
    function setQuotation(uint256 hashedQuotation) override external CheckMsgPubkey {
        tvm.accept();
        IElector(elector).setQuotation{value: SET_QUOTATION_COST}(hashedQuotation);
    }

    function requestRevealing(uint256 hashedQuotation) override external SenderIsElector {
        tvm.accept();
        emit RevealPlz(hashedQuotation);
    }

    function revealQuotation(uint128 oneUSDCost, uint256 salt, uint256 hashedQuotation) override external CheckMsgPubkey {
        tvm.accept();

        IElector(elector).revealQuotation{value: REVEAL_QUOTATION_COST}(oneUSDCost, salt);
    }

    function slash() override external SenderIsElector {
        tvm.accept();
        selfdestruct(elector);
    }

    // AFTER VALIDATION PHASE
    function cleanUp(address destination) override external CheckMsgPubkey AfterValidation {
        tvm.accept();
        selfdestruct(destination);
    }

    // MODIFIERS
    modifier CheckMsgPubkey() {
        require(msg.pubkey() == tvm.pubkey(), Errors.WRONG_PUB_KEY);
        _;
    }

    modifier SenderIsElector() {
        require(msg.sender == elector, Errors.WRONG_SENDER);
        _;
    }

    modifier AfterValidation() {
        require(now >= validationStartTime + validationDuration, Errors.WRONG_MOMENT);
        _;
    }
}
