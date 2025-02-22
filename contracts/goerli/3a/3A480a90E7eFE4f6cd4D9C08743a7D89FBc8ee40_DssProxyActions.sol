// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

interface GemLike {
    function allowance(address, address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function balanceOf(address) external view returns (uint);
}


interface ManagerLike {
    function cdpCan(address, uint, address) external view returns (uint);
    function ilks(uint) external view returns (bytes32);
    function owns(uint) external view returns (address);
    function urns(uint) external view returns (address);
    function vat() external view returns (address);
    function open(bytes32, address) external returns (uint);
    function give(uint, address) external;
    function cdpAllow(uint, address, uint) external;
    function urnAllow(address, uint) external;
    function frob(uint, int, int) external;
    function flux(uint, address, uint) external;
    function move(uint, address, uint) external;
    function exit(address, uint, address, uint) external;
    function quit(uint, address) external;
    function enter(address, uint) external;
    function shift(uint, uint) external;
}

interface VatLike {
    function can(address, address) external view returns (uint);
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
    function USB(address) external view returns (uint);
    function urns(bytes32, address) external view returns (uint, uint, uint);
    function frob(bytes32, address, address, address, int, int) external;
    function hope(address) external;
    function move(address, address, uint) external;
    function addDebt(bytes32 i, address u, uint wad) external;
    function subDebt(bytes32 i, address u, uint wad) external;

}

interface GemJoinLike {
    function dec() external returns (uint);
    function gem() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

interface GNTJoinLike {
    function bags(address) external view returns (address);
    function make(address) external returns (address);
}

interface USBJoinLike {
    function vat() external returns (VatLike);
    function USB() external returns (GemLike);
    function join(bytes32 , address, uint) external payable;
    function exit(bytes32, address , uint) external;
}

interface HopeLike {
    function hope(address) external;
    function nope(address) external;
}

interface EndLike {
    function fix(bytes32) external view returns (uint);
    function cash(bytes32, uint) external;
    function free(bytes32) external;
    function pack(uint) external;
    function skim(bytes32, address) external;
}

interface JugLike {
    function drip(bytes32) external returns (uint);
    function getFeeBorrow(bytes32) external returns (uint);
    function treasury() external returns (address);
}

interface PotLike {
    function pie(address) external view returns (uint);
    function balance(address) external view returns (uint);
    function drip() external returns (uint);
    function join(uint, uint, uint) external;
    function exit(uint, uint, uint) external;
}

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// WARNING: These functions meant to be used as a a library for a DSProxy. Some are unsafe if you call them directly.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

contract Common {
    uint256 constant RAY = 10 ** 27;

    // Internal functions

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    // Public functions

    function USBJoin_join(bytes32 ilk, address apt, address urn, uint wad) public {
        // Gets USB from the user's wallet
        USBJoinLike(apt).USB().transferFrom(msg.sender, address(this), wad);
        // Approves adapter to take the USB amount
        USBJoinLike(apt).USB().approve(apt, wad);
        // Joins USB into the vat
        USBJoinLike(apt).join(ilk, urn, wad);
    }
}

contract DssProxyActions is Common {
    uint constant decimal = 10000;
    //events
    event Deposit(address user, uint vault, uint amount);
    event Withdraw(address user, uint vault, uint amount);
    event Repay(address user, uint vault, uint amount, uint feeBorrow);
    event Borrow(address user, uint vault, uint amount);

    modifier onlyVaultOwner (address manager, uint cdp) {
        require(ManagerLike(manager).owns(cdp) == address(this) && msg.sender == ProxyLike(address(this)).owner(), "owner-missmatch");
        _;
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint wad) internal pure returns (uint rad) {
        rad = mul(wad, 10 ** 27);
    }

    function convertTo18(address gemJoin, uint256 amt) internal returns (uint256 wad) {
        // For those collaterals that have less than 18 decimals precision we need to do the conversion before passing to frob function
        // Adapters will automatically handle the difference of precision
        wad = mul(
            amt,
            10 ** (18 - GemJoinLike(gemJoin).dec())
        );
    }

    function _getDrawDart(
        address vat,
        address jug,
        address urn,
        bytes32 ilk,
        uint wad
    ) internal returns (int dart) {
        // Updates stability fee rate
        uint rate = JugLike(jug).drip(ilk);

        // Gets USB balance of the urn in the vat
        uint USB = VatLike(vat).USB(urn);

        // If there was already enough USB in the vat balance, just exits it without adding more debt
        if (USB < mul(wad, RAY)) {
            // Calculates the needed dart so together with the existing USB in the vat is enough to exit wad amount of USB tokens
            dart = toInt(sub(mul(wad, RAY), USB) / rate);
            // This is neeeded due lack of precision. It might need to sum an extra dart wei (for the given USB wad amount)
            dart = mul(uint(dart), rate) < mul(wad, RAY) ? dart + 1 : dart;
        }
    }

    function _getWipeDart(
        Info memory info,
        uint USB
    ) internal view returns (int dart) {
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(info.vat).ilks(info.ilk);
        // Gets actual art value of the urn
        (, uint art,) = VatLike(info.vat).urns(info.ilk, info.urn);

        // Uses the whole USB balance in the vat to reduce the debt
        dart = toInt(USB / rate);
        // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
        dart = uint(dart) <= art ? - dart : - toInt(art);
    }

    function _getWipeAllWad(
        address vat,
        address usr,
        address urn,
        bytes32 ilk
    ) internal view returns (uint wad) {
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint art,) = VatLike(vat).urns(ilk, urn);
        // Gets actual USB amount in the urn
        uint USB = VatLike(vat).USB(usr);

        uint rad = sub(mul(art, rate), USB);
        wad = rad / RAY;

        // If the rad precision has some dust, it will need to request for 1 extra wad wei
        wad = mul(wad, RAY) < rad ? wad + 1 : wad;
    }

    // Public functions

    function transfer(address gem, address dst, uint amt) public {
        GemLike(gem).transfer(dst, amt);
    }

    function ethJoin_join(address apt, address urn) public payable {
        // Wraps ETH in WETH
        GemJoinLike(apt).gem().deposit{value:(msg.value)}();
        // Approves adapter to take the WETH amount
        GemJoinLike(apt).gem().approve(address(apt), msg.value);
        // Joins WETH collateral into the vat
        GemJoinLike(apt).join(urn, msg.value);
    }

    function gemJoin_join(address apt, address urn, uint amt, bool transferFrom) public {
        // Only executes for tokens that have approval/transferFrom implementation
        if (transferFrom) {
            // Gets token from the user's wallet
            GemJoinLike(apt).gem().transferFrom(msg.sender, address(this), amt);
            // Approves adapter to take the token amount
            GemJoinLike(apt).gem().approve(apt, amt);
        }
        // Joins token collateral into the vat
        GemJoinLike(apt).join(urn, amt);        
    }

    function hope(
        address obj,
        address usr
    ) public {
        HopeLike(obj).hope(usr);
    }

    function nope(
        address obj,
        address usr
    ) public {
        HopeLike(obj).nope(usr);
    }

    function open(
        address manager,
        bytes32 ilk,
        address usr
    ) public returns (uint cdp) {
        cdp = ManagerLike(manager).open(ilk, usr);
    }

    // function give(
    //     address manager,
    //     uint cdp,
    //     address usr
    // ) public {
    //     ManagerLike(manager).give(cdp, usr);
    // }

    // function giveToProxy(
    //     address proxyRegistry,
    //     address manager,
    //     uint cdp,
    //     address dst
    // ) public {
    //     // Gets actual proxy address
    //     address proxy = ProxyRegistryLike(proxyRegistry).proxies(dst);
    //     // Checks if the proxy address already existed and dst address is still the owner
    //     if (proxy == address(0) || ProxyLike(proxy).owner() != dst) {
    //         uint csize;
    //         assembly {
    //             csize := extcodesize(dst)
    //         }
    //         // We want to avoid creating a proxy for a contract address that might not be able to handle proxies, then losing the CDP
    //         require(csize == 0, "Dst-is-a-contract");
    //         // Creates the proxy for the dst address
    //         proxy = ProxyRegistryLike(proxyRegistry).build(dst);
    //     }
    //     // Transfers CDP to the dst proxy
    //     give(manager, cdp, proxy);
    // }

    function cdpAllow(
        address manager,
        uint cdp,
        address usr,
        uint ok
    ) public {
        ManagerLike(manager).cdpAllow(cdp, usr, ok);
    }

    function urnAllow(
        address manager,
        address usr,
        uint ok
    ) public {
        ManagerLike(manager).urnAllow(usr, ok);
    }

    function flux(
        address manager,
        uint cdp,
        address dst,
        uint wad
    ) public {
        ManagerLike(manager).flux(cdp, dst, wad);
    }

    function move(
        address manager,
        uint cdp,
        address dst,
        uint rad
    ) public {
        ManagerLike(manager).move(cdp, dst, rad);
    }

    function frob(
        address manager,
        uint cdp,
        int dink,
        int dart
    ) public {
        ManagerLike(manager).frob(cdp, dink, dart);
    }

    function quit(
        address manager,
        uint cdp,
        address dst
    ) public {
        ManagerLike(manager).quit(cdp, dst);
    }

    // function enter(
    //     address manager,
    //     address src,
    //     uint cdp
    // ) public {
    //     ManagerLike(manager).enter(src, cdp);
    // }

    // function shift(
    //     address manager,
    //     uint cdpSrc,
    //     uint cdpOrg
    // ) public {
    //     ManagerLike(manager).shift(cdpSrc, cdpOrg);
    // }

    // function makeGemBag(
    //     address gemJoin
    // ) public returns (address bag) {
    //     bag = GNTJoinLike(gemJoin).make(address(this));
    // }

    function lockETH(
        address manager,
        address ethJoin,
        uint cdp
    ) public payable onlyVaultOwner(manager, cdp) {
        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(ethJoin, address(this));
        // Locks WETH amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            toInt(msg.value),
            0
        );
        emit Deposit(msg.sender, cdp, msg.value);
    }

    function lockGem(
        address manager,
        address gemJoin,
        uint cdp,
        uint amt,
        bool transferFrom
    ) public onlyVaultOwner(manager, cdp) {
        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(gemJoin, address(this), amt, transferFrom);
        // Locks token amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            toInt(convertTo18(gemJoin, amt)),
            0
        );
        emit Deposit(msg.sender, cdp, amt);
    }

    function freeETH(
        address manager,
        address ethJoin,
        uint cdp,
        uint wad
    ) public {
        // Unlocks WETH amount from the CDP
        frob(manager, cdp, -toInt(wad), 0);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wad);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wad);
        emit Withdraw(msg.sender, cdp, wad);
    }

    function freeGem(
        address manager,
        address gemJoin,
        uint cdp,
        uint amt
    ) public {
        uint wad = convertTo18(gemJoin, amt);
        // Unlocks token amount from the CDP
        frob(manager, cdp, -toInt(wad), 0);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wad);
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, wad);

        emit Withdraw(msg.sender, cdp, amt);
    }

    function exitETH(
        address manager,
        address ethJoin,
        uint cdp,
        uint wad
    ) public {
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wad);

        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wad);
    }

    function exitGem(
        address manager,
        address gemJoin,
        uint cdp,
        uint amt
    ) public {
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), convertTo18(gemJoin, amt));

        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }

    function draw(
        address manager,
        address jug,
        address USBJoin,
        uint cdp,
        uint wad
    ) public {
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Generates debt in the CDP
        frob(manager, cdp, 0, _getDrawDart(vat, jug, urn, ilk, wad));
        // Moves the USB amount (balance in the vat in rad) to proxy's address
        move(manager, cdp, address(this), toRad(wad));
        // Allows adapter to access to proxy's USB balance in the vat
        if (VatLike(vat).can(address(this), address(USBJoin)) == 0) {
            VatLike(vat).hope(USBJoin);
        }
        // Exits USB to the user's wallet as a token
        USBJoinLike(USBJoin).exit(ilk, msg.sender, wad);
        VatLike(vat).addDebt(ilk, urn, wad);
    
        emit Borrow(msg.sender, cdp, wad);
    }

    struct Info {
        address vat;
        address urn;
        bytes32 ilk;
    }
    function getInfo(address manager, uint cdp) internal view returns (Info memory info) {
        info.vat = ManagerLike(manager).vat();
        info.urn = ManagerLike(manager).urns(cdp);
        info.ilk = ManagerLike(manager).ilks(cdp);
    }

    function getDebtIssued(uint art , uint debt, uint rate) public pure returns(uint totalDebtIssued, uint accuralFee) {
        totalDebtIssued = art * rate / RAY;
        accuralFee = totalDebtIssued - debt;
    }

    function chargeFeeTreasury(Info memory info, address jug, uint repayAmount, address USBJoin) internal returns (uint feeTreasury) {
        (,uint art , uint debt) = VatLike(info.vat).urns(info.ilk, info.urn);
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(info.vat).ilks(info.ilk);
        uint fee = JugLike(jug).getFeeBorrow(info.ilk);
        (, uint accuralFee) = getDebtIssued(art, debt, rate);
        if(accuralFee > 0) {
            feeTreasury = repayAmount >= accuralFee ? accuralFee * fee / decimal : repayAmount * fee / decimal;
            if(feeTreasury > 0) {
                address treasury = JugLike(jug).treasury();
                USBJoinLike(USBJoin).USB().transferFrom(msg.sender, treasury, feeTreasury);
            }
        }
    }

    function wipeInternal(address own, address manager, address USBJoin, uint cdp, Info memory info, uint wad, uint feeTreasury) internal {
        if (own == address(this) || ManagerLike(manager).cdpCan(own, cdp, address(this)) == 1) {
            // Joins USB amount into the vat
            USBJoin_join(info.ilk, USBJoin, info.urn, wad - feeTreasury);
            // Paybacks debt to the CDP
            frob(manager, cdp, 0, _getWipeDart(info, VatLike(info.vat).USB(info.urn)));
        } else {
            // Joins USB amount into the vat
            USBJoin_join(info.ilk, USBJoin, address(this), wad - feeTreasury);
            // Paybacks debt to the CDP
            VatLike(info.vat).frob(
                info.ilk,
                info.urn,
                address(this),
                address(this),
                0,
                _getWipeDart(info, wad * RAY)
            );
        }
    }

    function calcDebt(Info memory info, uint art , uint debt, uint wad) internal {
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(info.vat).ilks(info.ilk);
        (uint totalDebtIssued, uint accuralFee) = getDebtIssued(art, debt, rate);
        wad = wad > accuralFee ? wad - accuralFee : 0;
        uint wadDebt;
        if(totalDebtIssued - wad >= debt && wad != debt) {
            wadDebt = 0;
        } else if (wad >= debt) {
            wadDebt = debt;
        } else {
            wadDebt = wad;
        }
        VatLike(info.vat).subDebt(info.ilk, info.urn, wadDebt);
    }

    function wipe(
        address manager,
        address USBJoin,
        address jug,
        uint cdp,
        uint wad
    ) public onlyVaultOwner(manager, cdp) {
        Info memory info = getInfo(manager, cdp);
        (, uint art, uint debt) = VatLike(info.vat).urns(info.ilk, info.urn);
        address own = ManagerLike(manager).owns(cdp);
        uint feeTreasury = chargeFeeTreasury (info, jug, wad, USBJoin);
        wipeInternal(own, manager, USBJoin, cdp, info, wad, feeTreasury);
        calcDebt(info, art, debt, wad);

        emit Repay(msg.sender, cdp, wad, feeTreasury);
    }

    function wipeAll(
        address manager,
        address USBJoin,
        address jug,
        uint cdp
    ) public onlyVaultOwner(manager, cdp) {
        Info memory info = getInfo(manager, cdp);
        (, uint art, uint debt) = VatLike(info.vat).urns(info.ilk, info.urn);
        address own = ManagerLike(manager).owns(cdp);
        uint feeTreasury;
        if (own == address(this) || ManagerLike(manager).cdpCan(own, cdp, address(this)) == 1) {
            // Joins USB amount into the vat
            uint amount = _getWipeAllWad(info.vat, info.urn, info.urn, info.ilk);
            feeTreasury = chargeFeeTreasury (info, jug, amount, USBJoin);
            USBJoin_join(info.ilk, USBJoin, info.urn, amount - feeTreasury);
            // Paybacks debt to the CDP
            frob(manager, cdp, 0, -int(art));
        } else {
            // Joins USB amount into the vat
            uint amount = _getWipeAllWad(info.vat, address(this), info.urn, info.ilk);
            feeTreasury = chargeFeeTreasury (info, jug, amount, USBJoin);
            USBJoin_join(info.ilk, USBJoin, address(this), amount - feeTreasury);
            // Paybacks debt to the CDP
            VatLike(info.vat).frob(
                info.ilk,
                info.urn,
                address(this),
                address(this),
                0,
                -int(art)
            );
        }
        calcDebt(info, art, debt, debt);

        emit Repay(msg.sender, cdp, art, feeTreasury); 
    }

    function lockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address USBJoin,
        uint cdp,
        uint wadD
    ) public payable {
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(ethJoin, urn);
        // Locks WETH amount into the CDP and generates debt
        frob(manager, cdp, toInt(msg.value), _getDrawDart(vat, jug, urn, ilk, wadD));
        // Moves the USB amount (balance in the vat in rad) to proxy's address
        move(manager, cdp, address(this), toRad(wadD));
        // Allows adapter to access to proxy's USB balance in the vat
        if (VatLike(vat).can(address(this), address(USBJoin)) == 0) {
            VatLike(vat).hope(USBJoin);
        }
        // Exits USB to the user's wallet as a token
        USBJoinLike(USBJoin).exit(ilk, msg.sender, wadD);
        VatLike(vat).addDebt(ilk, urn, wadD);

        emit Deposit(msg.sender, cdp, msg.value);
        emit Borrow(msg.sender, cdp, wadD);
    }

    function openLockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address USBJoin,
        bytes32 ilk,
        uint wadD
    ) public payable returns (uint cdp) {
        cdp = open(manager, ilk, address(this));
        lockETHAndDraw(manager, jug, ethJoin, USBJoin, cdp, wadD);
    }

    function lockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address USBJoin,
        uint cdp,
        uint amtC,
        uint wadD,
        bool transferFrom
    ) public {
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(gemJoin, urn, amtC, transferFrom);
        // Locks token amount into the CDP and generates debt
        int lockAmount = toInt(convertTo18(gemJoin, amtC));
        int debtAmount =_getDrawDart(vat, jug, urn, ilk, wadD);
        frob(manager, cdp, lockAmount, debtAmount);
        // Moves the USB amount (balance in the vat in rad) to proxy's address
        move(manager, cdp, address(this), toRad(wadD));
        // Allows adapter to access to proxy's USB balance in the vat
        if (VatLike(vat).can(address(this), address(USBJoin)) == 0) {
            VatLike(vat).hope(USBJoin);
        }
        // Exits USB to the user's wallet as a token
        USBJoinLike(USBJoin).exit(ilk, msg.sender, wadD);
        VatLike(vat).addDebt(ilk, urn, wadD);

        emit Deposit(msg.sender, cdp, amtC);
        emit Borrow(msg.sender, cdp,wadD);
    }

    function openLockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address USBJoin,
        bytes32 ilk,
        uint amtC,
        uint wadD,
        bool transferFrom
    ) public returns (uint cdp) {        
        cdp = open(manager, ilk, address(this));
        lockGemAndDraw(manager, jug, gemJoin, USBJoin, cdp, amtC, wadD, transferFrom);
    }

    // function openLockGNTAndDraw(
    //     address manager,
    //     address jug,
    //     address gntJoin,
    //     address USBJoin,
    //     bytes32 ilk,
    //     uint amtC,
    //     uint wadD
    // ) public returns (address bag, uint cdp) {
    //     // Creates bag (if doesn't exist) to hold GNT
    //     bag = GNTJoinLike(gntJoin).bags(address(this));
    //     if (bag == address(0)) {
    //         bag = makeGemBag(gntJoin);
    //     }
    //     // Transfer funds to the funds which previously were sent to the proxy
    //     GemLike(GemJoinLike(gntJoin).gem()).transfer(bag, amtC);
    //     cdp = openLockGemAndDraw(manager, jug, gntJoin, USBJoin, ilk, amtC, wadD, false);
    // }

    function wipeAndFreeETH(
        address manager,
        address ethJoin,
        address USBJoin,
        address jug,
        uint cdp,
        uint wadC,
        uint wadD
    ) public onlyVaultOwner(manager, cdp) {
        Info memory info = getInfo(manager, cdp);
        // Joins USB amount into the vat
        uint feeTreasury = chargeFeeTreasury (info, jug, wadD, USBJoin);
        
        USBJoin_join(info.ilk, USBJoin, info.urn, wadD - feeTreasury);
        
        // Paybacks debt to the CDP and unlocks WETH amount from it
        int dart = _getWipeDart(
            info,
            VatLike(ManagerLike(manager).vat()).USB(info.urn)
        );

        frob(
            manager,
            cdp,
            -toInt(wadC),
            dart
        );
        (, uint art, uint debt) = VatLike(info.vat).urns(info.ilk, info.urn);
        calcDebt(info, art, debt, wadD);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wadC);
        emit Repay(msg.sender, cdp, wadD, feeTreasury);
        emit Withdraw(msg.sender, cdp, wadC);
    }

    function wipeAllAndFreeETH(
        address manager,
        address ethJoin,
        address USBJoin,
        address jug,
        uint cdp,
        uint wadC
    ) public onlyVaultOwner(manager, cdp) {
        Info memory info = getInfo(manager, cdp);
        (, uint art, uint debt) = VatLike(info.vat).urns(info.ilk, info.urn);
        uint amount = _getWipeAllWad(info.vat, info.urn, info.urn, info.ilk);
        uint feeTreasury = chargeFeeTreasury (info, jug, amount, USBJoin);

        // Joins USB amount into the vat
        USBJoin_join(info.ilk, USBJoin, info.urn, amount - feeTreasury);
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(
            manager,
            cdp,
            -toInt(wadC),
            -int(art)
        );
        calcDebt(info, art, debt, debt);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wadC);
        emit Repay(msg.sender, cdp, art, feeTreasury);
        emit Withdraw(msg.sender, cdp, wadC);
    }

    function wipeAndFreeGem(
        address manager,
        address gemJoin,
        address USBJoin,
        address jug,
        uint cdp,
        uint amtC,
        uint wadD
    ) public onlyVaultOwner(manager, cdp) {
        Info memory info = getInfo(manager, cdp);
        uint feeTreasury = chargeFeeTreasury (info, jug, wadD, USBJoin);
        // Joins USB amount into the vat
        USBJoin_join(info.ilk, USBJoin, info.urn, wadD - feeTreasury);
        
        uint wadC = convertTo18(gemJoin, amtC);
        int dart = _getWipeDart(
            info,
            VatLike(ManagerLike(manager).vat()).USB(info.urn)         
        );
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(
            manager,
            cdp,
            -toInt(wadC),
            dart
        );
        (,uint art, uint debt) = VatLike(info.vat).urns(info.ilk, info.urn);
        calcDebt(info, art, debt, wadD);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, wadC);
        emit Repay(msg.sender, cdp, wadD, feeTreasury);
        emit Withdraw(msg.sender, cdp, wadC);
    }

    function wipeAllAndFreeGem(
        address manager,
        address gemJoin,
        address USBJoin,
        address jug,
        uint cdp,
        uint amtC
    ) public onlyVaultOwner(manager, cdp) {
        Info memory info = getInfo(manager, cdp);
        (, uint art, uint debt) = VatLike(info.vat).urns(info.ilk, info.urn);
        uint amount = _getWipeAllWad(info.vat, info.urn, info.urn, info.ilk);
        uint feeTreasury = chargeFeeTreasury (info, jug, amount, USBJoin);
        // Joins USB amount into the vat
        USBJoin_join(info.ilk, USBJoin, info.urn, amount - feeTreasury);
        
        uint wadC = convertTo18(gemJoin, amtC);
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(
            manager,
            cdp,
            -toInt(wadC),
            -int(art)
        );
        calcDebt(info, art, debt, debt);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, wadC);

        emit Repay(msg.sender, cdp, art, feeTreasury);
        emit Withdraw(msg.sender, cdp, amtC);
    }
}

contract DssProxyActionsEnd is Common {
    // Internal functions

    function _free(
        address manager,
        address end,
        uint cdp
    ) internal returns (uint ink) {
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        address urn = ManagerLike(manager).urns(cdp);
        VatLike vat = VatLike(ManagerLike(manager).vat());
        uint art;
        (ink, art,) = vat.urns(ilk, urn);

        // If CDP still has debt, it needs to be paid
        if (art > 0) {
            EndLike(end).skim(ilk, urn);
            (ink,,) = vat.urns(ilk, urn);
        }
        // Approves the manager to transfer the position to proxy's address in the vatm
        if (vat.can(address(this), address(manager)) == 0) {
            vat.hope(manager);
        }
        // Transfers position from CDP to the proxy address
        ManagerLike(manager).quit(cdp, address(this));
        // Frees the position and recovers the collateral in the vat registry
        EndLike(end).free(ilk);
    }

    // Public functions
    function freeETH(
        address manager,
        address ethJoin,
        address end,
        uint cdp
    ) public {
        uint wad = _free(manager, end, cdp);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wad);
    }

    function freeGem(
        address manager,
        address gemJoin,
        address end,
        uint cdp
    ) public {
        uint amt = _free(manager, end, cdp) / 10 ** (18 - GemJoinLike(gemJoin).dec());
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }

    function pack(
        address USBJoin,
        address end,
        uint wad
    ) public {
        USBJoin_join(bytes32(0), USBJoin, address(this), wad);
        VatLike vat = USBJoinLike(USBJoin).vat();
        // Approves the end to take out USB from the proxy's balance in the vat
        if (vat.can(address(this), address(end)) == 0) {
            vat.hope(end);
        }
        EndLike(end).pack(wad);
    }

    function cashETH(
        address ethJoin,
        address end,
        bytes32 ilk,
        uint wad
    ) public {
        EndLike(end).cash(ilk, wad);
        uint wadC = mul(wad, EndLike(end).fix(ilk)) / RAY;
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wadC);
    }

    function cashGem(
        address gemJoin,
        address end,
        bytes32 ilk,
        uint wad
    ) public {
        EndLike(end).cash(ilk, wad);
        // Exits token amount to the user's wallet as a token
        uint amt = mul(wad, EndLike(end).fix(ilk)) / RAY / 10 ** (18 - GemJoinLike(gemJoin).dec());
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }
}

contract DssProxyActionsDsr is Common {

    function join(
        address USBJoin,
        address pot,
        uint wad
    ) public {
        VatLike vat = USBJoinLike(USBJoin).vat();
        // Executes drip to get the chi rate updated to rho == now, otherwise join will fail
        uint chi = PotLike(pot).drip();
        // Joins wad amount to the vat balance
        USBJoin_join(bytes32(0), USBJoin, address(this), wad);
        // Approves the pot to take out USB from the proxy's balance in the vat
        if (vat.can(address(this), address(pot)) == 0) {
            vat.hope(pot);
        }
        // Joins the pie value (equivalent to the USB wad amount) in the pot
        PotLike(pot).join(mul(wad, RAY) / chi, wad, chi);
    }

    function exit(
        address USBJoin,
        address pot,
        uint wad
    ) public {
        VatLike vat = USBJoinLike(USBJoin).vat();
        // Executes drip to count the savings accumulated until this moment
        uint chi = PotLike(pot).drip();
        // Calculates the pie value in the pot equivalent to the USB wad amount
        uint pie = mul(wad, RAY) / chi;
        // Exits USB from the pot
        PotLike(pot).exit(pie, wad, chi);
        // Checks the actual balance of USB in the vat after the pot exit
        uint bal = USBJoinLike(USBJoin).vat().USB(address(this));
        // Allows adapter to access to proxy's USB balance in the vat
        if (vat.can(address(this), address(USBJoin)) == 0) {
            vat.hope(USBJoin);
        }
        // It is necessary to check if due rounding the exact wad amount can be exited by the adapter.
        // Otherwise it will do the maximum USB balance in the vat
        USBJoinLike(USBJoin).exit(
            bytes32(0),
            msg.sender,
            bal >= mul(wad, RAY) ? wad : bal / RAY
        );
    }

    function exitAll(
        address USBJoin,
        address pot
    ) public {
        VatLike vat = USBJoinLike(USBJoin).vat();
        // Executes drip to count the savings accumulated until this moment
        uint chi = PotLike(pot).drip();
        uint balanceDeposit = PotLike(pot).balance(address(this));
        // Gets the total pie belonging to the proxy address
        uint pie = PotLike(pot).pie(address(this));
        // Exits USB from the pot
        PotLike(pot).exit(pie, balanceDeposit, chi);
        // Allows adapter to access to proxy's USB balance in the vat
        if (vat.can(address(this), address(USBJoin)) == 0) {
            vat.hope(USBJoin);
        }
        // Exits the USB amount corresponding to the value of pie
        USBJoinLike(USBJoin).exit(bytes32(0), msg.sender, mul(chi, pie) / RAY);
    }
}