// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-auth/auth.sol";

interface AuthLike {
    function rely(address) external;
    function deny(address) external;
}

interface DependLike {
    function depend(bytes32, address) external;
}

interface BorrowerDeployerLike {
    function feed() external returns (address);
    function shelf() external returns (address);
    function title() external returns (address);
}

interface LenderDeployerLike {
    function assessor() external returns (address);
    function reserve() external returns (address);
    function poolAdmin() external returns (address);
}

interface AdapterDeployerLike {
    function mgr() external returns (address);
    function wireAdapter() external;
}

interface PoolAdminLike {
    function setAdminLevel(address, uint256) external;
}

contract TinlakeRoot is Auth {
    BorrowerDeployerLike public borrowerDeployer;
    LenderDeployerLike public lenderDeployer;
    AdapterDeployerLike public adapterDeployer;

    bool public deployed;
    address public deployUsr;
    address public immutable governance;

    address public oracle;
    address[] public level1Admins;
    address public level3Admin;

    constructor(address deployUsr_, address governance_) {
        deployUsr = deployUsr_;
        governance = governance_;
        wards[governance_] = 1;
        emit Rely(governance_);
    }

    // --- Prepare ---
    // Sets the two deployer dependencies. This needs to be called by the deployUsr
    function prepare(
        address lender_,
        address borrower_,
        address adapter_,
        address oracle_,
        address[] memory level1Admins_,
        address level3Admin_
    ) public {
        require(deployUsr == msg.sender);

        borrowerDeployer = BorrowerDeployerLike(borrower_);
        lenderDeployer = LenderDeployerLike(lender_);
        if (adapter_ != address(0)) adapterDeployer = AdapterDeployerLike(adapter_);
        oracle = oracle_;
        level1Admins = level1Admins_;
        level3Admin = level3Admin_;

        deployUsr = address(0); // disallow the deploy user to call this more than once.
    }

    function prepare(address lender_, address borrower_, address adapter_) public {
        prepare(lender_, borrower_, adapter_, address(0), new address[](0), address(0));
    }

    function prepare(address lender_, address borrower_) public {
        prepare(lender_, borrower_, address(0), address(0), new address[](0), address(0));
    }

    // --- Deploy ---
    // After going through the deploy process on the lender and borrower method, this method is called to connect
    // lender and borrower contracts.
    function deploy() public {
        require(address(borrowerDeployer) != address(0) && address(lenderDeployer) != address(0) && deployed == false);
        deployed = true;
        address reserve_ = lenderDeployer.reserve();
        address shelf_ = borrowerDeployer.shelf();
        address assessor_ = lenderDeployer.assessor();

        // Borrower depends
        DependLike(borrowerDeployer.shelf()).depend("reserve", reserve_);
        DependLike(borrowerDeployer.shelf()).depend("assessor", assessor_);

        // Lender depends
        address navFeed = borrowerDeployer.feed();

        // shelf can deposit and payout from reserve
        AuthLike(reserve_).rely(shelf_);
        DependLike(assessor_).depend("navFeed", navFeed);

        // Lender wards
        if (oracle != address(0)) AuthLike(navFeed).rely(oracle);

        DependLike(lenderDeployer.poolAdmin()).depend("navFeed", navFeed);
        AuthLike(navFeed).rely(lenderDeployer.poolAdmin());

        PoolAdminLike poolAdmin = PoolAdminLike(lenderDeployer.poolAdmin());
        poolAdmin.setAdminLevel(governance, 3);
        poolAdmin.setAdminLevel(level3Admin, 3);

        for (uint256 i = 0; i < level1Admins.length; i++) {
            poolAdmin.setAdminLevel(level1Admins[i], 1);
        }
    }

    // --- Governance Functions ---
    // `relyContract` & `denyContract` can be called by any ward on the TinlakeRoot
    // contract to make an arbitrary address a ward on any contract the TinlakeRoot
    // is a ward on.
    function relyContract(address target, address usr) public auth {
        AuthLike(target).rely(usr);
    }

    function denyContract(address target, address usr) public auth {
        AuthLike(target).deny(usr);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) Centrifuge 2020, based on MakerDAO dss https://github.com/makerdao/dss
pragma solidity >=0.5.15;

contract Auth {
    mapping (address => uint256) public wards;
    
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    modifier auth {
        require(wards[msg.sender] == 1, "not-authorized");
        _;
    }

}