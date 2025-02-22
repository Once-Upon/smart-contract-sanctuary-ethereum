/**
 *Submitted for verification at Etherscan.io on 2022-10-20
*/

// SPDX-License-Identifier: GPL-3.0-or-later

// Copyright (C) 2017-2020 Maker Ecosystem Growth Holdings, INC.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.10;

contract LibNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  usr,
        bytes32  indexed  arg1,
        bytes32  indexed  arg2,
        bytes             data
    ) anonymous;

    modifier note {
        _;
        assembly {
            // log an 'anonymous' event with a constant 6 words of calldata
            // and four indexed topics: selector, caller, arg1 and arg2
            let mark := msize()                         // end of memory ensures zero
            mstore(0x40, add(mark, 288))              // update free memory pointer
            mstore(mark, 0x20)                        // bytes type data offset
            mstore(add(mark, 0x20), 224)              // bytes size (padded)
            calldatacopy(add(mark, 0x40), 0, 224)     // bytes payload
            log4(mark, 288,                           // calldata
                 shl(224, shr(224, calldataload(0))), // msg.sig
                 caller(),                              // msg.sender
                 calldataload(4),                     // arg1
                 calldataload(36)                     // arg2
                )
        }
    }
}


contract Mosm is LibNote {
    // Authorized users
    mapping (bytes32 => mapping (address => uint)) public wards;

    // Whitelisted feed readers, set by an auth
    mapping (bytes32 => mapping (address => uint256)) public bud;

// contract Median {
    // --- Auth ---
    function median_rely(address usr) external note median_auth { wards["median"][usr] = 1; }
    function median_deny(address usr) external note median_auth { wards["median"][usr] = 0; }

    modifier median_auth {
        require(wards["median"][msg.sender] == 1, "Median/not-authorized");
        _;
    }

    uint128        val;
    uint32  public age;
    bytes32 public constant wat = "ethusd"; // You want to change this every deploy
    uint256 public bar = 1;

    // Authorized oracles, set by an auth
    mapping (address => uint256) public orcl;

    // Mapping for at most 256 oracles
    mapping (uint8 => address) public slot;

    modifier toll { require(bud["median"][msg.sender] == 1, "Median/contract-not-whitelisted"); _;}

    event LogMedianPrice(uint256 val, uint256 age);

    //Set type of Oracle
    constructor() public {
        wards["median"][msg.sender] = 1;
        wards["osm"][msg.sender] = 1;
        bud["median"][address(this)] = 1; // Deployer by default gets read access
        bud["osm"][msg.sender] = 1;
    }

    function median_read() external view toll returns (uint256) {
        require(val > 0, "Median/invalid-price-feed");
        return val;
    }

    function median_peek() external view toll returns (uint256,bool) {
        return (val, val > 0);
    }

    function recover(uint256 val_, uint32 age_, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        return ecrecover(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(val_, age_, wat)))),
            v, r, s
        );
    }

    // Median
    function poke(
        uint256[] calldata val_, uint32[] calldata age_,
        uint8[] calldata v, bytes32[] calldata r, bytes32[] calldata s) external
    {
        require(val_.length == bar, "Median/bar-too-low");

        uint256 bloom = 0;
        uint256 last = 0;
        uint32 snooze = age;

        for (uint i = 0; i < val_.length; i++) {
            // Validate the values were signed by an authorized oracle
            address signer = recover(val_[i], age_[i], v[i], r[i], s[i]);
            // Check that signer is an oracle
            require(orcl[signer] == 1, "Median/invalid-oracle");
            // Price feed age greater than last medianizer age
            require(age_[i] > snooze, "Median/stale-message");
            // Check for ordered values
            require(val_[i] >= last, "Median/messages-not-in-order");
            last = val_[i];
            // Bloom filter for signer uniqueness
            uint8 sl = uint8(uint256(signer) >> 152);
            require((bloom >> sl) % 2 == 0, "Median/oracle-already-signed");
            bloom += uint256(2) ** sl;
        }

        val = uint128(val_[val_.length >> 1]);
        age = uint32(block.timestamp);

        emit LogMedianPrice(val, age);
    }

    function lift(address[] calldata a) external note median_auth {
        for (uint i = 0; i < a.length; i++) {
            require(a[i] != address(0), "Median/no-oracle-0");
            uint8 s = uint8(uint256(a[i]) >> 152);
            require(slot[s] == address(0), "Median/signer-already-exists");
            orcl[a[i]] = 1;
            slot[s] = a[i];
        }
    }

    function drop(address[] calldata a) external note median_auth {
       for (uint i = 0; i < a.length; i++) {
            orcl[a[i]] = 0;
            slot[uint8(uint256(a[i]) >> 152)] = address(0);
       }
    }

    function setBar(uint256 bar_) external note median_auth {
        require(bar_ > 0, "Median/quorum-is-zero");
        require(bar_ % 2 != 0, "Median/quorum-not-odd-number");
        bar = bar_;
    }

    function median_kiss(address a) external note median_auth {
        require(a != address(0), "Median/no-contract-0");
        bud["median"][a] = 1;
    }

    function median_diss(address a) external note median_auth {
        bud["median"][a] = 0;
    }

    function median_kiss(address[] calldata a) external note median_auth {
        for(uint i = 0; i < a.length; i++) {
            require(a[i] != address(0), "Median/no-contract-0");
            bud["median"][a[i]] = 1;
        }
    }

    function median_diss(address[] calldata a) external note median_auth {
        for(uint i = 0; i < a.length; i++) {
            bud["median"][a[i]] = 0;
        }
    }
//} contract Median

// contract OSM {
    function osm_rely(address usr) external note osm_auth { wards["osm"][usr] = 1; }
    function osm_deny(address usr) external note osm_auth { wards["osm"][usr] = 0; }
    modifier osm_auth {
        require(wards["osm"][msg.sender] == 1, "OSM/not-authorized");
        _;
    }

    // --- Stop ---
    uint256 public stopped;
    modifier stoppable { require(stopped == 0, "OSM/is-stopped"); _; }

    // --- Math ---
    function add(uint64 x, uint64 y) internal pure returns (uint64 z) {
        z = x + y;
        require(z >= x);
    }

    uint16 constant ONE_HOUR = uint16(3600);
    uint16 public hop = ONE_HOUR;
    uint64 public zzz;

    struct Feed {
        uint128 val;
        uint128 has;
    }

    Feed cur;
    Feed nxt;

    modifier osm_toll { require(bud["osm"][msg.sender] == 1, "OSM/contract-not-whitelisted"); _; }

    event LogValue(bytes32 val);

    function stop() external note osm_auth {
        stopped = 1;
    }

    function start() external note osm_auth {
        stopped = 0;
    }

    function era() internal view returns (uint) {
        return block.timestamp;
    }

    function step(uint16 ts) external osm_auth {
        require(ts > 0, "OSM/ts-is-zero");
        hop = ts;
    }

    function void() external note osm_auth {
        cur = nxt = Feed(0, 0);
        stopped = 1;
    }

    function pass() public view returns (bool) {
        return era() >= add(zzz, hop);
    }

    function noop(uint256 wut) public view returns (bool) {
        bool has = cur.has == 1 && nxt.has == 1;
        bool allequal = cur.val == nxt.val && cur.val == uint128(wut);
        return has && allequal;
    }

    // OSM
    function poke() external note stoppable {
        require(pass(), "OSM/not-passed");

        // Ask the Median side of the contract for the current price
        (uint256 wut, bool ok) = this.median_peek();

        // If there is no change save some gas
        require(!noop(wut), 'OSM/no-op');

        if (ok) {
            cur = nxt;
            nxt = Feed(uint128(wut), 1);
            zzz = uint64(era());
            emit LogValue(bytes32(uint(cur.val)));
        }
    }

    function peek() external view osm_toll returns (bytes32,bool) {
        return (bytes32(uint(cur.val)), cur.has == 1);
    }

    function peep() external view osm_toll returns (bytes32,bool) {
        return (bytes32(uint(nxt.val)), nxt.has == 1);
    }

    function read() external view osm_toll returns (bytes32) {
        require(cur.has == 1, "OSM/no-current-value");
        return (bytes32(uint(cur.val)));
    }

    function kiss(address a) external note osm_auth {
        require(a != address(0), "OSM/no-contract-0");
        bud["osm"][a] = 1;
    }

    function diss(address a) external note osm_auth {
        bud["osm"][a] = 0;
    }

    function kiss(address[] calldata a) external note osm_auth {
        for(uint i = 0; i < a.length; i++) {
            require(a[i] != address(0), "OSM/no-contract-0");
            bud["osm"][a[i]] = 1;
        }
    }

    function diss(address[] calldata a) external note osm_auth {
        for(uint i = 0; i < a.length; i++) {
            bud["osm"][a[i]] = 0;
        }
    }
//} contract OSM

}

contract MosmETHUSD is Mosm {
    bytes32 public constant wat = "ETHUSD";

    function recover(uint256 val_, uint32 age_, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        return ecrecover(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(val_, age_, wat)))),
            v, r, s
        );
    }
}