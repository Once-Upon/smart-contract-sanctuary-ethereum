// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../OtoCoJurisdictionV2.sol";

contract JurisdictionDelawareV2 is OtoCoJurisdictionV2 {

    constructor (
        uint256 renewPrice,
        uint256 deployPrice,
        string memory name,
        string memory defaultBadge,
        string memory goldBadge
    ) OtoCoJurisdictionV2(renewPrice, deployPrice, name, defaultBadge, goldBadge, false) {}

    /**
     * @dev See {OtoCoJurisdiction-getSeriesNameFormatted}.
     */
    function getSeriesNameFormatted (
        uint256 count,
        string calldata nameToFormat
    ) public pure override returns(string memory){
        return string(abi.encodePacked(nameToFormat, ' LLC'));
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract OtoCoJurisdictionV2 {

    string private name;
    string private defaultBadge;
    string private goldBadge;
    uint256 private renewCost;
    uint256 private deployCost;
    bool private standalone;

    constructor (
        uint256 _renewCost,
        uint256 _deployCost,
        string memory _name,
        string memory _defaultBadge,
        string memory _goldBadge,
        bool _standalone
    ) {
        renewCost = _renewCost;
        deployCost = _deployCost;
        name = _name;
        defaultBadge = _defaultBadge;
        goldBadge = _goldBadge;

        assembly {
            // we avoid initializing default values
            if iszero(iszero(_standalone)) {
                sstore(standalone.slot, _standalone)
            }
        }
    }

    /**
     * Get formatted name according to the jurisdiction requirement.
     * To use when create new series, before series creation.
     * Returns the string name formatted accordingly.
     *
     * @param count current number of series deployed at the jurisdiction.
     * @return nameToFormat name of the series to format accordingly.
     */
    function getSeriesNameFormatted(uint256 count, string calldata nameToFormat) public pure virtual returns(string memory);
    
    /**
     * Return the name of the jurisdiction.
     * 
     * @return name the name of the jurisdiction.
     */
    function getJurisdictionName() external view returns(string memory) {
        return name;
    }

    /**
     * Return the NFT URI link of the jurisdiction.
     * 
     * @return defaultBadge the badge URI.
     */
    function getJurisdictionBadge() external view returns(string memory) {
        return defaultBadge;
    }

    /**
     * Return the Gold NFT URI link of the jurisdiction.
     * 
     * @return goldBadge the gold badge URI.
     */
    function getJurisdictionGoldBadge() external view returns(string memory) {
        return goldBadge;
    }


    /**
     * Return the renewal price in USD.
     * 
     * @return renewCost the cost to renew a entity of this jurisdiction for 1 year.
     */
    function getJurisdictionRenewalPrice() external view returns(uint256) {
        return renewCost;
    }

    /**
     * Return the renewal price in USD.
     * 
     * @return deployCost the cost to renew a entity of this jurisdiction for 1 year.
     */
    function getJurisdictionDeployPrice() external view returns(uint256) {
        return deployCost;
    }

    function isStandalone() external view returns(bool) {
        return standalone;
    }
}