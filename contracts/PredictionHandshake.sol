/*
* PredictionExchange is an exchange contract that doesn't accept bets on the outcomes,
* but instead matchedes backers (those betting on odds) with layers (those offering the 
* odds).
*
* Code conventions:
*       - side: 0 (unknown), 1 (support), 2 (against)
*       - role: 0 (unknown), 1 (maker), 2 (taker)
*
*/

pragma solidity ^0.4.18;

contract PredictionHandshake {

        struct Order {
                uint stake;
                uint payout;
        }

        struct Market {
                address initiator;
                uint closingTime; 
                uint outcome;
                mapping(address => mapping(uint => Order)) open; // address => side => order
                mapping(address => mapping(uint => Order)) matched; // address => side => order
        }

        Market[] public markets;
        address public root;

        uint public REPORT_WINDOW = 4 hours;

        function PredictionHandshake() public {
                root = msg.sender;
        } 

        event __init(uint hid, bytes32 offchain); 

        function init(uint closingTime, bytes32 offchain) public payable {
                Market memory m;
                m.initiator = msg.sender;
                m.closingTime = now + closingTime * 1 seconds;
                markets.push(m);
                __init(markets.length - 1, offchain);
        }

        event __shake(uint hid, bytes32 offchain);

        function shake(uint hid, uint role, uint side, uint payout, address maker, bytes32 offchain) public payable {
                Market storage m = markets[hid];
                require(now < m.closingTime);
                if (role == 1) {
                        m.open[msg.sender][side].stake += msg.value;
                        m.open[msg.sender][side].payout += payout;
                } else if (role == 2) {
                        m.matched[msg.sender][side].stake += msg.value;
                        m.matched[msg.sender][side].payout += payout;
                        m.matched[maker][3-side].stake += (payout - msg.value);
                        m.matched[maker][3-side].payout += payout;
                        m.open[maker][3-side].stake -= (payout - msg.value);
                        m.open[maker][3-side].payout -= payout;
                }
                __shake(hid, offchain);
        }

        event __withdraw(uint hid, bytes32 offchain);

        function withdraw(uint hid, bytes32 offchain) public onlyPredictor(hid) {
                Market storage m = markets[hid]; 
                require(now > m.closingTime);
                if (m.outcome != 0) 
                        msg.sender.transfer(m.matched[msg.sender][m.outcome].payout +
                                            m.open[msg.sender][1].stake + 
                                            m.open[msg.sender][2].stake);
                else if (now > m.closingTime + REPORT_WINDOW) 
                        msg.sender.transfer(m.matched[msg.sender][1].stake + 
                                            m.matched[msg.sender][2].stake + 
                                            m.open[msg.sender][1].stake + 
                                            m.open[msg.sender][2].stake);
                __withdraw(hid, offchain);
        }

        event __report(uint hid, bytes32 offchain);

        function report(uint hid, uint outcome, bytes32 offchain) public onlyRoot() {
                markets[hid].outcome = outcome;
                __report(hid, offchain);
        }

        modifier onlyPredictor(uint hid) {
                require(markets[hid].matched[msg.sender][1].stake > 0 || 
                        markets[hid].matched[msg.sender][2].stake > 0 || 
                        markets[hid].open[msg.sender][1].stake > 0 || 
                        markets[hid].open[msg.sender][2].stake > 0);
                _;
        }

        modifier onlyRoot() {
                require(msg.sender == root);
                _;
        }
}