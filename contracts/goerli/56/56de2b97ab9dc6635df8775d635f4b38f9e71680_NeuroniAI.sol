//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "./Interfaces.sol";
import "./Libraries.sol";
import "./BaseErc20.sol";
import "./Burnable.sol";
import "./Taxable.sol";
import "./TaxDistributor.sol";
import "./AntiSniper.sol";

contract NeuroniAI is BaseErc20, AntiSniper, Burnable, Taxable {

    constructor () {
        configure(0x75659bC8752676E749d662ce4F6De82f4BCc0BE6);

        symbol = "NEURONI";
        name = "Neuroni.AI";
        decimals = 18;

        // Swap
        address routerAddress = getRouterAddress();
        IDEXRouter router = IDEXRouter(routerAddress);
        address WBNB = router.WETH();
        address pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
        exchanges[pair] = true;
        taxDistributor = new TaxDistributor(routerAddress, pair, WBNB, 1300, 1300);

        // Anti Sniper
        enableSniperBlocking = true;
        isNeverSniper[address(taxDistributor)] = true;
        mhPercentage = 300;

        // Tax
        minimumTimeBetweenSwaps = 5 minutes;
        minimumTokensBeforeSwap = 1000 * 10 ** decimals;
        excludedFromTax[address(taxDistributor)] = true;
        taxDistributor.createWalletTax("Insight", 190, 456, 0xc1F910B8230508DCee02FB8a34CCB0Af7Cb24F42, true);
        taxDistributor.createWalletTax("Marketing", 185, 444, 0x75659bC8752676E749d662ce4F6De82f4BCc0BE6, true);
        taxDistributor.createWalletTax("Dev", 125, 300, 0x08a3351E0C1eb65C5D80D568AdbE97810820d7E3, true);
        autoSwapTax = false;

        // Burnable
        ableToBurn[address(taxDistributor)] = true;

        // Finalise
        _allowed[address(taxDistributor)][routerAddress] = 2**256 - 1;
        _totalSupply = _totalSupply + (10_000_000 * 10 ** decimals);
        _balances[owner] = _balances[owner] + _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }


    // Overrides
    
    function launch() public override(AntiSniper, BaseErc20) onlyOwner {
        super.launch();
    }

    function configure(address _owner) internal override(AntiSniper, Burnable, Taxable, BaseErc20) {
        super.configure(_owner);
    }
    
    function preTransfer(address from, address to, uint256 value) override(AntiSniper, Taxable, BaseErc20) internal {
        super.preTransfer(from, to, value);
    }
    
    function calculateTransferAmount(address from, address to, uint256 value) override(AntiSniper, Taxable, BaseErc20) internal returns (uint256) {
        return super.calculateTransferAmount(from, to, value);
    }
    
    function postTransfer(address from, address to) override(BaseErc20) internal {
        super.postTransfer(from, to);
    }

}