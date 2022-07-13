pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EscrowPaymentSplitter {
    using SafeMath for uint256;

    IERC20 token;

    address public manager;
    address public pinetreeAdminAddress;
    string public constant genSymbol = "GEN";
    string public constant ethSymbol = "ETH";

    mapping(address => Escrow) public escrowPaymentMap;

    struct Escrow{
        uint orderId;
        string paymentToken;
        uint256 escrowAmount;
        address royaltyAddress;
        // Royalty Fee: 1.5% = 15 / 1000: royaltyFeeBase1000 is 15
        uint256 royaltyFeeBase1000;
        address sellerAddress;
        uint timestamp;
        string hmac;
        bool payout;
    }

    event TransferReceived(address _from, uint _amount);

    receive() payable external {
        // 0.000001
        uint _minAmount = 1*(10**12);
        require(msg.value >= _minAmount, "You need to send at least 0.000001 ETH");
        require(!escrowPaymentMap[msg.sender].payout, "Already payout");
        require(keccak256(bytes(escrowPaymentMap[msg.sender].paymentToken)) == keccak256(bytes(ethSymbol)), "Not matched ETH");
        require(escrowPaymentMap[msg.sender].escrowAmount == msg.value, "Not matched escrow amount");

        escrowPaymentMap[msg.sender].payout = true;
        
        // pinetree fee 2.5%
        uint distributedAmountForPinetree = (msg.value).mul(25).div(1000);
        payable(pinetreeAdminAddress).transfer(distributedAmountForPinetree);
        emit TransferReceived(pinetreeAdminAddress, distributedAmountForPinetree);
        
        // royalty
        uint distributedAmountForRoyalty = (msg.value).mul(escrowPaymentMap[msg.sender].royaltyFeeBase1000).div(1000);
        payable(escrowPaymentMap[msg.sender].royaltyAddress).transfer(distributedAmountForRoyalty);
        emit TransferReceived(escrowPaymentMap[msg.sender].royaltyAddress, distributedAmountForRoyalty);
        
        // seller
        uint distributedAmountForSeller = (msg.value).sub(distributedAmountForPinetree).sub(distributedAmountForRoyalty);
        payable(escrowPaymentMap[msg.sender].sellerAddress).transfer(distributedAmountForSeller);
        emit TransferReceived(escrowPaymentMap[msg.sender].sellerAddress, distributedAmountForSeller);
    }

    constructor(address _addressToken, address _pinetreeAdminAddress) { 
        manager = msg.sender;
        token = IERC20(_addressToken);

        pinetreeAdminAddress = _pinetreeAdminAddress;
    }

    function version() public pure returns (string memory) {
        return "0.0.1";
    }

    function name() public pure returns (string memory) {
        return "EscrowPaymentSplitter";
    }

    // event for EVM logging
    event ManagerSet(address indexed oldManager, address indexed newManager);

    // modifier to check if caller is manager
    modifier isManager() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == manager, "Caller is not manager");
        _;
    }
    
    function changeManager(address newManager) public isManager {
        emit ManagerSet(manager, newManager);
        manager = newManager;
    }

    function getManager() external view returns (address) {
        return manager;
    }

    function addEscrowPaymentInfo(uint _orderId, string memory _paymentToken, uint256 _escrowAmount, address _royaltyAddress, uint256 _royaltyFeeBase1000, address _sellerAddress, uint _timestamp, string memory _hmac) public {
        require(keccak256(bytes(_paymentToken)) == keccak256(bytes(genSymbol)) || keccak256(bytes(_paymentToken)) == keccak256(bytes(ethSymbol)), "Not provided paymentToken, ETH or GEN");
        uint _minAmount = 1*(10**12);
        require(_escrowAmount >= _minAmount, "You need to send at least 0.000001 ETH");
        require(_royaltyFeeBase1000 < 1000, "Invalid royaltyFeeBase1000");
        escrowPaymentMap[msg.sender] = Escrow(_orderId, _paymentToken, _escrowAmount, _royaltyAddress, _royaltyFeeBase1000, _sellerAddress, _timestamp, _hmac, false);
    }
    
    // GEN
    function receiveTokens(uint256 _amount) public {
        require(keccak256(bytes(escrowPaymentMap[msg.sender].paymentToken)) == keccak256(bytes(genSymbol)), "Not matched GEN");

        uint _minAmount = 1*(10**18);
        require(_amount >= _minAmount, "You need to send at least 1 GEN");

        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");

        require(!escrowPaymentMap[msg.sender].payout, "Already payout");
        require(escrowPaymentMap[msg.sender].escrowAmount == _amount, "No matching amount number");

        escrowPaymentMap[msg.sender].payout = true;

        // pinetree fee 1.5%
        // If the GEN is not deposited, it will be reverted.
        uint256 amountForPinetree = _amount.mul(15).div(1000);
        token.transferFrom(msg.sender, pinetreeAdminAddress, amountForPinetree);
        
        uint256 amountForRoyalty = _amount.mul(escrowPaymentMap[msg.sender].royaltyFeeBase1000).div(1000);
        token.transferFrom(msg.sender, escrowPaymentMap[msg.sender].royaltyAddress, amountForRoyalty);

        uint256 amountRemained = _amount.sub(amountForPinetree).sub(amountForRoyalty);
        token.transferFrom(msg.sender, escrowPaymentMap[msg.sender].sellerAddress, amountRemained);
    }

    function getEthBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdrawETH() public isManager {
        payable(msg.sender).transfer(address(this).balance);
    }
}
