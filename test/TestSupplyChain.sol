pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";

contract Participant {
    SupplyChain private supplyChain;

    function () external payable {}

    constructor(SupplyChain _supplyChain) public {
        supplyChain = _supplyChain;
    }

    function addItem(string memory _name, uint _price) public {
        supplyChain.addItem(_name, _price);
    }

    function buy(uint _sku, uint _amount) public returns (bool success) {
        (success, ) = address(supplyChain).call.gas(1000000).value(_amount)(abi.encodeWithSignature("buyItem(uint256)", _sku));
    }

    function ship(uint _sku) public returns (bool success) {
        (success, ) = address(supplyChain).call(abi.encodeWithSignature("shipItem(uint256)", _sku));
    }

    function receive(uint _sku) public returns (bool success) {
        (success, ) = address(supplyChain).call(abi.encodeWithSignature("receiveItem(uint256)", _sku));
    }
}

contract SupplyChainCreator {
    SupplyChain private supplyChain;

    function () external payable {}

    function set(SupplyChain _supplyChain) public {
        supplyChain = _supplyChain;
    }
}

contract TestSupplyChain {
    uint public initialBalance = 1 ether;
    uint public participantInitialBalance = 5000 wei;
    uint public itemPrice = 1000 wei;
    uint public excessAmount = 2000 wei;

    Participant private seller;
    Participant private buyer;

    SupplyChain private supplyChain;
    SupplyChainCreator private supplyChainCreator;

    function () external payable {}

    constructor() public payable {}

    function setupContracts() public {
        supplyChainCreator = new SupplyChainCreator();
        supplyChain = new SupplyChain();
        supplyChainCreator.set(supplyChain);

        seller = createParticipant(supplyChain);
        buyer = createParticipant(supplyChain);

        seller.addItem("TestItem", itemPrice);
    }

    function createParticipant(SupplyChain _supplyChain) internal returns (Participant) {
        Participant participant = new Participant(_supplyChain);
        address(participant).transfer(participantInitialBalance);
        return participant;
    }

    modifier setup {
        setupContracts();
        _;
    }

    modifier buyBefore(uint _sku) {
        bool status = buyer.buy(_sku, excessAmount);
        Assert.equal(status, true, "Purchase should be successful");
        _;
    }

    modifier shipBefore(uint _sku) {
        bool status = seller.ship(_sku);
        Assert.equal(status, true, "The item should ship successfully");
        _;
    }

    modifier receiveBefore(uint _sku) {
        bool status = buyer.receive(0);
        Assert.equal(status, true, "The item should be received");
        _;
    }

    // buyItem
    // test for failure if user does not send enough funds
    function testPurchaseWithNoSufficientFunds() public setup {
        bool status = buyer.buy(0, 1 wei);
        Assert.isFalse(status, "Purchase should fail if user does not send enough funds");
    }

    // // test for purchasing an item that is not for Sale
    function testBuyingANonExistantItem() public setup {
        bool status = buyer.buy(1, excessAmount);
        Assert.isFalse(status, "Purchase should fail if the item does not exist");
    }

    function testBuyingAnItemNotForSale() public setup buyBefore(0) {
        (,,,SupplyChain.State state,,) = supplyChain.items(0);
        Assert.equal(uint(state), 1, "The state should change to Sold");
        bool status = seller.buy(0, excessAmount);
        Assert.isFalse(status, "Purchasing an already sold item should fail");
    }

    // shipItem
    // test for calls that are made by not the seller
    function testShippingIfNotTheSeller() public setup buyBefore(0) {
        (,,,SupplyChain.State state,,) = supplyChain.items(0);
        Assert.equal(uint(state), 1, "The state of the item should be Sold");
        bool status = buyer.ship(0);
        Assert.isFalse(status, "Shipping can only be made by the seller");
    }

    // test for trying to ship an item that is not marked Sold
    function testShippingIfItemNotSold() public setup {
        (,,,SupplyChain.State state,,) = supplyChain.items(0);
        Assert.equal(uint(state), 0, "The state of the item should be ForSale");
        bool status = seller.ship(0);
        Assert.isFalse(status, "Shipping can only be made if the item has been sold");
    }

    function testShippingIfItemAlreadyShipped() public setup buyBefore(0) shipBefore(0) {
        (,,,SupplyChain.State state,,) = supplyChain.items(0);
        Assert.equal(uint(state), 2, "The state of the item should be Shipped");
        bool status = seller.ship(0);
        Assert.isFalse(status, "The shipmet should fail since the item is already shipped");
    }

    // receiveItem
    // test calling the function from an address that is not the buyer
    function testReceivingAnItemIfNotTheBuyer() public setup buyBefore(0) shipBefore(0) {
        (,,,SupplyChain.State state,,) = supplyChain.items(0);
        Assert.equal(uint(state), 2, "The state of the item should be Shipped");
        bool status = seller.receive(0);
        Assert.isFalse(status, "Only the buyer should be able to receive the item");
    }

    // test calling the function on an item not marked Shipped
    function testReceivingAnItemThatWasNotShipped() public setup buyBefore(0) {
        (,,,SupplyChain.State state,,) = supplyChain.items(0);
        Assert.equal(uint(state), 1, "The state of the item should be Sold");
        bool status = buyer.receive(0);
        Assert.isFalse(status, "Cannot receive the item that has not been shipped");
    }

    function testReceivingAnAlreadyReceivedItem() public setup buyBefore(0) shipBefore(0) receiveBefore(0) {
        (,,,SupplyChain.State state,,) = supplyChain.items(0);
        Assert.equal(uint(state), 3, "The state of the item should be Received");
        bool status = buyer.receive(0);
        Assert.isFalse(status, "Item already received");
    }
}
