/**
 *Submitted for verification at Etherscan.io on 2023-05-31
*/

// File: Optimized Amira Code v2/Genraters.sol


pragma solidity >=0.4.25 <0.9.0;

contract GenratesAndConversion {
    function random(uint256 _count) public view returns (bytes32) {
        return (
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    // block.prevrandao,
                    msg.sender,
                    _count
                )
            )
        );
    }

    function toBytes(address a) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
    }

    function genrateUniqueIDByProductName(string memory _materialname)
        external
        pure
        returns (bytes32)
    {
        bytes32 hash = keccak256(abi.encodePacked(_materialname));
        return hash;
    }
}

// File: Optimized Amira Code v2/Library.sol


pragma solidity >=0.4.25 <0.9.0;

library Types {
    enum StakeHolder {
        //currently we have only 2 stakeholder so, that's why I'm using
        Producer, //0 for producer.
        ManuFacturer, // 1 for manfacturer at the registeration time.
        distributors, // 2
        retailers, // 3
        supplier //4
    }

    enum productAvailablity {
        PRODUCED,
        ready_to_ship,
        pre_bookable,
        READY_FOR_PICKUP,
        PICKED_UP,
        SHIPMENT_RELEASED,
        RECEIVED_SHIPMENT,
        READY_FOR_SALE,
        PAID,
        SOLD
    }

    //stakeholder details
    struct Stakeholder {
        StakeHolder role;
        address id_;
        string name;
        string email;
        uint256 MobNo;
        bool IsRegistered;
        string country;
        string city;
    }

    //Product => RawMaterial
    struct Product {
        uint256 ArrayIndex; //flag for checking the availablity
        bytes32 PId; // => now we created an auto genrated uid for each product using product name!
        string MaterialName;
        uint256 AvailableDate;
        uint256 Quantity;
        uint256 ExpiryDate;
        uint256 Price;
        bool IsAdded; //flag for checking the availablity
        productAvailablity status;
    }

    struct manfProduct {
        uint256 ArrIndex;
        string name;
        bytes32 PId;
        string description;
        uint256 expDateEpoch;
        string barcodeId;
        uint256 quantity;
        uint256 price;
        uint256 weights;
        uint256 manDateEpoch; //available date
        productAvailablity status;
    }

    struct UserHistory {
        address id_;
        manfProduct Product_;
        uint256 orderTime_;
    }

    struct productAvailableManuf {
        address id;
        string productName;
        bytes32 productID;
        uint256 quantity;
        uint256 price;
        uint256 availableDate;
        uint256 weights;
        uint256 expDateEpoch;
    }

    struct SupplierWithMaterialID {
        address id_; // account Id of the user
        uint256 quantity_;
        bytes32 productId_; // Added, Purchased date in epoch in UTC timezone
        uint256 supplyprice_;
    }

    struct PurchaseOrderHistoryM {
        address _id;
        address _supplierID;
        SupplierWithMaterialID _product;
        uint256 _quantity;
        uint256 _orderTime;
    }

    struct PurchaseOrderHistoryD {
        address _id;
        manfProduct _product;
        uint256 _quantity;
        uint256 _orderTime;
    }

    struct PurchaseOrderHistoryR {
        address _id;
        manfProduct _product;
        uint256 _quantity;
        uint256 _orderTime;
    }

    struct MaterialHistory {
        PurchaseOrderHistoryM manufacturer;
    }

    struct ProductHistory {
        PurchaseOrderHistoryD distributor;
    }

    struct ProductHistoryRetail {
        PurchaseOrderHistoryR retailer;
    }
    
    struct OrderPlaced {
        uint256 orderSrNo;
        address ManufAdd;
        bytes32 PId;
        string Materialname;
        uint256 Qty;
        uint256 PreOrderQty; //Not yet Placed That Why Inventory Not Deducted Total Quantity when Available Time Is Coming we can updated.
        uint256 ExpiryDate;
        bool IsOrderPlaced;
    }
}

// File: Optimized Amira Code v2/Register.sol


pragma solidity ^0.8.15;



contract StakeHolderRegistration {
    GenratesAndConversion genr;

    constructor(GenratesAndConversion _genr) {
        genr = _genr;
    }

    Types.Stakeholder[] internal producerList;
    Types.Stakeholder[] internal manufacturerList;
    Types.Stakeholder[] internal distributorsList;
    Types.Stakeholder[] internal retailersList;
    Types.Stakeholder[] internal supplierList;

    mapping(address => bytes32[3])  stakeholderspharse;
    mapping(address => Types.Stakeholder) internal stakeholders;
    mapping(string => Types.Stakeholder[]) internal servesCountry;
    mapping(string => Types.Stakeholder[]) internal distributoresServesCountry;
    mapping(string => Types.Stakeholder[]) internal supplierServesCountry;
    mapping(string => Types.Stakeholder[]) internal retailersServesCity;

    mapping(address => Types.Stakeholder[])
        internal distributerLinkedWithmanufacturer;
    mapping(address => Types.Stakeholder[])
        internal retailersLinkedWithdistributer;

    event StakeHolderRegisterd(
        Types.StakeHolder role,
        address id_,
        string name,
        string email,
        uint256 MobNo,
        bool IsRegistered,
        bytes32[3],
        string country,
        string city
    );

    //before adding raw materials(products) producer needs to be register yourself first then only he/she can createhis Invenotry.
    // always registerd with unique ID if alraedy registered.
    //all the stakeholders can Register Via This.
    function Register(
        Types.StakeHolder _role,
        string memory _name,
        string memory _email,
        uint256 _mobNo,
        string memory _country,
        string memory _city
    ) public returns (string memory) {
        // Producer And ManuFacturer Both Have Different Adress Must!
        require(msg.sender != address(0));
        require(!stakeholders[msg.sender].IsRegistered == true, 
            "stakeholder alraedy registered with a role!");
        
        Types.Stakeholder memory sk_ = Types.Stakeholder({
            role: _role,
            id_: msg.sender,
            name: _name,
            email: _email,
            MobNo: _mobNo,
            IsRegistered: true,
            country: _country,
            city: _city
        });
        add(sk_);

        bytes32 g1 = genr.random(1);
        bytes32 g2 = genr.random(2);
        bytes32 g3 = genr.random(3);
        stakeholderspharse[msg.sender] = [g1, g2, g3];

        //if stake holder is producer then only can add Producer list
        if (Types.StakeHolder.Producer == _role) {
            producerList.push(sk_);
        }
        //if stake holder is producer then only can add Manufacturer list
        else if (Types.StakeHolder.ManuFacturer == _role) {
            manufacturerList.push(sk_);
            servesCountry[_country].push(sk_);
        }
        //if stake holder is producer then only can add Distributors list
        else if (Types.StakeHolder.distributors == _role) {
            distributorsList.push(sk_);
            distributoresServesCountry[_country].push(sk_);
        }
        //if stake holder is producer then only can add Retailers list
        else if (Types.StakeHolder.retailers == _role) {
            retailersList.push(sk_);
            retailersServesCity[_city].push(sk_);
        } 
        
        else if (Types.StakeHolder.supplier == _role) {
            supplierList.push(sk_);
            supplierServesCountry[_country].push(sk_);
        }

        emit StakeHolderRegisterd(
            _role,
            msg.sender,
            _name,
            _email,
            _mobNo,
            true,
            stakeholderspharse[msg.sender],
            _country,
            _city
        );

        return "successfully registered!";
    }

    function userRegisterUnderOtherStakeHolder(
        //(if user registered under other stakeholders like under manufacturer registered distributors and retailers same for others.)
        Types.StakeHolder _role,
        address _userref,
        string memory _name,
        string memory _email,
        uint256 _mobNo,
        string memory _country,
        string memory _city
    ) public returns (string memory) {
        require(msg.sender != address(0));
        
        require(!stakeholders[msg.sender].IsRegistered == true,     //not working here 
            "stakeholder alraedy registered with a role!");

        require(
            (Types.StakeHolder.distributors == _role ||
                Types.StakeHolder.retailers == _role),
            "Under Manufacturer Can only Select Distributors and Retailers Role!"
        );

        require(
            (stakeholders[_userref].role == Types.StakeHolder.ManuFacturer ||
                stakeholders[_userref].role == Types.StakeHolder.distributors),
            "only under Manufacturer and Distributors you can register yourself!"
        );

        bytes32 g1 = genr.random(1);
        bytes32 g2 = genr.random(2);
        bytes32 g3 = genr.random(3);
        stakeholderspharse[msg.sender] = [g1, g2, g3];

        Types.Stakeholder memory sk_ = Types.Stakeholder({
            role: _role,
            id_: msg.sender,
            name: _name,
            email: _email,
            MobNo: _mobNo,
            IsRegistered: true,
            country: _country,
            city: _city
        });
        add(sk_);
        if (
            Types.StakeHolder.ManuFacturer == stakeholders[_userref].role ||
            Types.StakeHolder.distributors == _role
        ) {
            distributorsList.push(sk_);
            distributoresServesCountry[_country].push(sk_);
            distributerLinkedWithmanufacturer[_userref].push(sk_);
        }
        //if stake holder is producer then only can add Retailers list
        else if (
            Types.StakeHolder.distributors == stakeholders[_userref].role ||
            Types.StakeHolder.retailers == _role
        ) {
            retailersList.push(sk_);
            retailersServesCity[_city].push(sk_);
            retailersLinkedWithdistributer[_userref].push(sk_);
        }

        return "successfully registered!";
    }

    // /Login StakeHolders
    function login(
        address id,
        bytes32 pharse,
        Types.StakeHolder _role
    ) public view returns (bool) {
        if (stakeholders[id].role == _role) {
            if (
                stakeholderspharse[id][0] == pharse ||
                stakeholderspharse[id][1] == pharse ||
                stakeholderspharse[id][0] == pharse
            ) {
                return true;
            }
        }
        return false;
    }

    function getStakeHolderDetails(address id_)
        external
        view
        returns (Types.Stakeholder memory)
    {
        require(id_ != address(0));
        require(stakeholders[id_].id_ != address(0));
        return stakeholders[id_];
    }
    
    //used at producer list
    function getProducerList()
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return producerList;
    }

    //list of manufacturer
    function getManuFacturerList()
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return manufacturerList;
    }

    //list of distributors
    function getDistributorsList()
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return distributorsList;
    }

    //list of retailers
    function getRetailersList()
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return retailersList;
    }

    //list of supplier
    function getSupplierList()
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return supplierList;
    }

    //list of distributersLinkedWithManufacturers
    function getStakeHolderListLinkedManufacturer(address _manufAdd)
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return distributerLinkedWithmanufacturer[_manufAdd];
    }

    //list of stakeholder linked with other distributer
    function getStakeHolderListLinkedWithDistributer(address _distAdd)
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return retailersLinkedWithdistributer[_distAdd];
    }

    //list of manufacturer list via countryname
    function getDistViaCountryServe(string memory _countryName)
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return distributoresServesCountry[_countryName];
    }

    //list of manufacturer list via countryname
    function getManufViaCountryServe(string memory _countryName)
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return servesCountry[_countryName];
    }

    //list of suppliers list via countryname
    function getSupplierViaCountryServe(string memory _countryName)
        public
        view
        returns (Types.Stakeholder[] memory)
    {
        return supplierServesCountry[_countryName];
    }

    function add(Types.Stakeholder memory user) internal {
        require(user.id_ != address(0));
        stakeholders[user.id_] = user;
    }

    function getPhrases() public view returns (bytes32, bytes32, bytes32) {
        require(
            stakeholderspharse[msg.sender][0] != bytes32(0),
            "User not registered"
        );
        return (
        stakeholderspharse[msg.sender][0],
        stakeholderspharse[msg.sender][1],
        stakeholderspharse[msg.sender][2]
        );
    }

    // function getRole(address user) internal view returns (Types.StakeHolder) {
    //     require(
    //         stakeholders[user].id_ != address(0),
    //         "User not registered"
    //     );
    //     return stakeholders[user].role;
    // }
    // // //restrictions 
    // // function has(Types.StakeHolder role, address account)
    // //     private
    // //     view
    // //     returns (bool)
    // // {
    // //     require(account != address(0));
    // //     return (account != address(0) &&
    // //         stakeholders[account].role == role);
    // // }
}

// File: Optimized Amira Code v2/Supplier.sol


pragma solidity ^0.8.15;



contract Supplier {
    Types.SupplierWithMaterialID[] internal supplierWithMaterialID;
    mapping(address => mapping(bytes32 => Types.SupplierWithMaterialID))
        internal supplierPrices;
    mapping(bytes32 => Types.SupplierWithMaterialID[]) supplierMaterialID;

    event supplierSet(
        address id_, // account Id of the user
        bytes32 productid_,
        uint256 orderTime_
    );

    function supplierSetMaterialIDandPrice(
        bytes32 productid_,
        uint256 supplyprice_,
        uint256 quantity_
    ) public {
        // require(Types.Stakeholder.IsRegistered==true,"supplier not registered!");
        Types.SupplierWithMaterialID memory supplierMaterialID_ = Types
            .SupplierWithMaterialID({
                id_: msg.sender,
                quantity_: quantity_,
                productId_: productid_,
                supplyprice_: supplyprice_
            });

        supplierMaterialID[productid_].push(supplierMaterialID_);
        supplierPrices[msg.sender][productid_] = (supplierMaterialID_);
        supplierWithMaterialID.push(supplierMaterialID_);
        emit supplierSet(msg.sender, productid_, supplyprice_);
    }

    // function
}