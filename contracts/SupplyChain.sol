/*
    This exercise has been updated to use Solidity version 0.5
    Breaking changes from 0.4 to 0.5 can be found here: 
    https://solidity.readthedocs.io/en/v0.5.0/050-breaking-changes.html
*/

pragma solidity ^0.5.0;

contract SupplyChain {

    address public owner;
    uint public skuCount;

    mapping (uint => Item) public items;

    enum State {
        ForSale,
        Sold,
        Shipped,
        Received
    }

    struct Item {
        string name;
        uint sku;
        uint price;
        State state;
        address payable seller;
        address payable buyer;
    }

    event LogForSale(uint sku);
    event LogSold(uint sku);
    event LogShipped(uint sku);
    event LogReceived(uint sku);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier verifyCaller(address _address) {
        require (msg.sender == _address);
        _;
    }

    modifier paidEnough(uint _price) {
        require(msg.value >= _price);
        _;
    }

    modifier checkValue(uint _sku) {
        _;
        uint _price = items[_sku].price;
        uint amountToRefund = msg.value - _price;
        items[_sku].buyer.transfer(amountToRefund);
    }

    modifier forSale(uint _sku) {
        Item memory item = items[_sku];
        require(item.state == State.ForSale && item.seller != address(0x0));
        _;
    }

    modifier sold(uint _sku) {
        Item memory item = items[_sku];
        require(item.state == State.Sold);
        _;
    }

    modifier shipped(uint _sku) {
        Item memory item = items[_sku];
        require(item.state == State.Shipped);
        _;
    }

    modifier received(uint _sku) {
        Item memory item = items[_sku];
        require(item.state == State.Received);
        _;
    }

    constructor() public {
        owner = msg.sender;
        skuCount = 0;
    }

    function addItem(string memory _name, uint _price) public returns(bool) {
        emit LogForSale(skuCount);
        items[skuCount] = Item({name: _name, sku: skuCount, price: _price, state: State.ForSale, seller: msg.sender, buyer: address(0)});
        skuCount = skuCount + 1;
        return true;
    }

    function buyItem(uint _sku) public payable forSale(_sku) paidEnough(items[_sku].price) checkValue(_sku) {
        Item storage item = items[_sku];
        item.seller.transfer(item.price);
        item.buyer = msg.sender;
        item.state = State.Sold;
        emit LogSold(_sku);
    }

    function shipItem(uint _sku) public sold(_sku) verifyCaller(items[_sku].seller) {
        Item storage item = items[_sku];
        item.state = State.Shipped;
        emit LogShipped(_sku);
    }

    function receiveItem(uint _sku) public shipped(_sku) verifyCaller(items[_sku].buyer) {
        Item storage item = items[_sku];
        item.state = State.Received;
        emit LogReceived(_sku);
    }

    function fetchItem(uint _sku) public view returns (string memory name, uint sku, uint price, uint state, address seller, address buyer) {
        name = items[_sku].name;
        sku = items[_sku].sku;
        price = items[_sku].price;
        state = uint(items[_sku].state);
        seller = items[_sku].seller;
        buyer = items[_sku].buyer;
        return (name, sku, price, state, seller, buyer);
    }
}