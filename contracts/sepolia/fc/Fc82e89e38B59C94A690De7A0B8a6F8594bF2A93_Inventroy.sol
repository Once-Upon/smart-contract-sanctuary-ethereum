/**
 *Submitted for verification at Etherscan.io on 2023-06-07
*/

// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/Genraters.sol


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

// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/Library.sol


pragma solidity >=0.4.25 <0.9.0;

library Types {
   
   enum StakeHolder {      //currently we have only 2 stakeholder so, that's why I'm using  
        Producer, //0 for producer.
        ManuFacturer, // 1 for manfacturer at the registeration time.
        distributors, // 2
        retailers, // 3
        supplier,//4
        consumer
    }
    
    enum State {
        PRODUCED,
        PROCESSED,
        ready_to_ship,
        pre_bookable, 
        PICKUP,  
        SHIPMENT_RELEASED, 
        RECEIVED_SHIPMENT,
        DELIVERED, 
        READY_FOR_SALE,
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
        // address distributorID;
        // address retailerID;
        }

    //Product => RawMaterial
    struct Item {
        uint256 ArrayIndex; //flag for checking the availablity
        bytes32 PId; // => now we created an auto genrated uid for each product using product name!
        string MaterialName;
        uint256 AvailableDate;
        uint256 Quantity;
        uint256 ExpiryDate;
        uint256 Price;
        bool IsAdded; //flag for checking the availablity
        State itemState;
        uint256 prebookCount;
    }

    struct manfItem { 
        uint256 ArrIndex;        
        string name;
        bytes32 PId;
        string description;
        uint256 expDateEpoch;
        string barcodeId;
        uint256 quantity;
        uint256 price;
        uint256 weights;
        uint256 manDateEpoch;       //available date
        uint256 prebookCount;
        State itemState;
    }

    struct UserHistory {
        address id_;
        manfItem Product_;
        uint256 orderTime_;  
    }

    struct productAvailableManuf {
        address id;
        string  productName;
        bytes32 productID;
        uint256 quantity;
        uint256 price;
        uint256 availableDate;
        uint256 weights;
        uint256 expDateEpoch;
    }

    struct SupplierWithMaterialID  {
        address id_; // account Id of the user
        bytes32 itemId_;// Added, Purchased date in epoch in UTC timezone
        uint256 supplyprice_;
    }

    struct PurchaseOrderHistoryM {
        address manufacturerid;
        address supplierId;
        address producerId;
        Item rawMaterial;
        uint256 orderTime;  
    }

    struct PurchaseOrderHistoryD {
        address distributorId;
        address manufacturerid;
        address supplierId;
        manfItem product;
        uint256 orderTime;  
    }

    
    struct PurchaseOrderHistoryR {
        address retailerId;
        address distributorId;
        address supplierId;
        manfItem product;
        uint256 orderTime;  
    }
       
    struct MaterialHistory {
        PurchaseOrderHistoryM manufacturer;    
    }            

    struct ProductHistory   {    
        PurchaseOrderHistoryD distributor;
    }

    struct ProductHistoryRetail {    
        PurchaseOrderHistoryR retailer;
    }

}
// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/Register.sol


pragma solidity ^0.8.15;



contract StakeHolderRegistration {
    GenratesAndConversion genr;

    constructor(GenratesAndConversion _genr) {
        genr = _genr;
        emit AuthorizedCaller(msg.sender);
    }

    Types.Stakeholder[] internal producerList;
    Types.Stakeholder[] internal manufacturerList;
    Types.Stakeholder[] internal distributorsList;
    Types.Stakeholder[] internal retailersList;
    Types.Stakeholder[] internal supplierList;
    Types.Stakeholder[] internal consumerList;

    mapping(address => bytes32[3]) stakeholderspharse; //internal
    mapping(address => Types.Stakeholder) internal stakeholders;
    mapping(string => Types.Stakeholder[]) internal servesCountry;
    mapping(string => Types.Stakeholder[]) internal distributoresServesCountry;
    mapping(string => Types.Stakeholder[]) internal supplierServesCountry;
    mapping(string => Types.Stakeholder[]) internal retailersServesCity;

    mapping(address => Types.Stakeholder[])
        internal distributerLinkedWithmanufacturer;
    mapping(address => Types.Stakeholder[])
        internal retailersLinkedWithdistributer;

    event AuthorizedCaller(address caller);
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
        require(
            !stakeholders[msg.sender].IsRegistered == true,
            "stakeholder alraedy registered with a role!"
        );

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
        else if(Types.StakeHolder.supplier == _role){
            consumerList.push(sk_);
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

    //Login StakeHolders
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

        require(
            !stakeholders[msg.sender].IsRegistered == true, //not working here
            "stakeholder alraedy registered with a role!"
        );

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
}

// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/Inventory.sol


pragma solidity ^0.8.15;




contract Inventroy {
    
    GenratesAndConversion genCn;
    StakeHolderRegistration register;

    constructor(GenratesAndConversion _genCn, StakeHolderRegistration _registration){
        genCn = _genCn;
        register = _registration;
    }

    mapping(address => Types.Item[]) public producerInventor;  //public to internal
    mapping(address => mapping(bytes32 => Types.Item)) public rawMaterials; //mapping change public to normal
    mapping(address => Types.manfItem[]) public manufacturerInventor;
    mapping(address => mapping(bytes32 => Types.manfItem)) public manufacturedProduct;
    mapping(string => Types.productAvailableManuf[]) internal sameproductLinkedWithManufacturer;
    

    //raw materials added In inventory
    event AddedInInventory(
        bytes32 _uniqueId,
        string _materialName,
        uint256 _quantity,
        uint256 _availableDate,
        uint256 _expiryDate,
        uint256 _price
    );

    //when Inventory Updated at the producer end
    event InventoryUpdate(
        bytes32 _pid,
        uint256 _quantity,
        uint256 _availableDate,
        uint256 _expiryDate,
        uint256 _price
    );

    //when Manufacturer added Product
    event ManufacturedProductAdded(
        string _productName,
        address _manufacturerAddress,
        string _barcodeId,
        uint256 _availableDate,
        uint256 _expiryDate,
        Types.State status
    );

    //when Manufacturer update The Product
    event ManufacturedProductUpdated(
        string _prodName,
        address _manufacturerAddress,
        uint256 _availableDate,
        uint256 _expiryDate,
        bytes32 _updatedHash
    );

    //added raw material for creating Inventory at the producer end!
    function addRawMaterial(
        string memory _materialname,
        uint256 _quantity,
        uint256 _producingDate,
        uint256 _expiryDate,
        uint256 _price
    ) public {
        require(
            register.getStakeHolderDetails(msg.sender).role ==
                Types.StakeHolder.Producer,
            "only producer can add raw materials in inventory!!"
        );
        bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_materialname); //creates unique key using product name
        
        if(_pidHash == rawMaterials[msg.sender][_pidHash].PId){
            updateRawMaterial(_pidHash, _quantity+=_quantity, _producingDate, _expiryDate, _price);
        }
        else  {           
        
        Types.Item memory newRawMaterial = Types.Item({
            ArrayIndex: producerInventor[msg.sender].length,
            PId: _pidHash,
            MaterialName: _materialname,
            Quantity: _quantity,
            AvailableDate: _producingDate,
            ExpiryDate: _expiryDate,
            Price: _price,
            IsAdded: true,
            itemState: Types.State.PRODUCED,
            prebookCount: 0
        });

        rawMaterials[msg.sender][_pidHash] = newRawMaterial;
        addItemsInInventory(rawMaterials[msg.sender][_pidHash]);

            emit AddedInInventory(
                _pidHash,
                _materialname,
                _quantity,
                _producingDate,
                _expiryDate,
                _price
            );
        }
    }

    // Function to update the quantity and price of a raw material from producer side!
    function updateRawMaterial(
        bytes32 _pid,
        uint256 _quantity,
        uint256 _availableDate,
        uint256 _expiryDate,
        uint256 _price
    ) internal {
        Types.Item memory updateMaterial = rawMaterials[msg.sender][_pid];
    
        updateMaterial.AvailableDate = _availableDate;
        updateMaterial.ExpiryDate = _expiryDate;
        updateMaterial.Quantity = _quantity;
        updateMaterial.Price = _price;

        //logic implemented here by adding ArrayIndex
        Types.Item[] memory products = producerInventor[msg.sender];
        uint256 index = rawMaterials[msg.sender][_pid].ArrayIndex;

        products[index].AvailableDate = _availableDate;
        products[index].ExpiryDate = _expiryDate;
        products[index].Quantity = _quantity;
        products[index].Price = _price;

        emit InventoryUpdate(
            _pid,
            _quantity,
            _availableDate,
            _expiryDate,
            _price
        );
    }

    //for adding new raw material in Inventory and also adding at modified Inventory!
    function addItemsInInventory(Types.Item storage _newRawMaterial)
        private
    {
        producerInventor[msg.sender].push(_newRawMaterial);
    }

    // return all the Inventory function with modify one too
    // this function also used at manufacturer side too.
    function getProducerItems(address _producerID)
        public
        view
        returns (Types.Item[] memory)
    {
        return producerInventor[_producerID];
    }

    //this function not working! 
    function getAddedMaterialDetails(bytes32 _pidHash)
       external
        view
        returns (Types.Item memory)
    {   
        // bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_materialName);
        return rawMaterials[msg.sender][_pidHash];
    }

    function getAddedMaterialDetails(address _producerID, bytes32 _productID)
        external
        view
        returns (Types.Item memory)
    {   
        return rawMaterials[_producerID][_productID];
    }

    // forchecking Inventory producer can check Inventroy is added or not by passing product name.
    function IsAddedInInventory(string memory _materialName)
        public    //change external to internal
        view
        returns (bool)
    {
        bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_materialName);
        return (keccak256(
            abi.encodePacked((rawMaterials[msg.sender][_pidHash].MaterialName))
        ) == keccak256(abi.encodePacked((_materialName))));
    }

    //Manufacturer Product Adding

    function addManuFacturedProduct(
        string memory _prodName,
        string memory _description,
        uint256 _expiryDate,
        string memory _barcodeId,
        uint256 _quantity,
        uint256 _price,
        uint256 _weights,
        uint256 _availableDate
    ) public 
    {
         require(register.getStakeHolderDetails(msg.sender).role == Types.StakeHolder.ManuFacturer,
        "only Manufacturer can add Product in inventory!!");
        bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_prodName);
        if(_pidHash == manufacturedProduct[msg.sender][_pidHash].PId){
            updateAProduct(_prodName, _pidHash, _description, _expiryDate, _quantity+=_quantity, _price, _weights, _availableDate);
        }
        else    {
        Types.manfItem memory manufProduct_ = Types.manfItem({
            ArrIndex: manufacturerInventor[msg.sender].length,
            name: _prodName,
            PId: _pidHash,
            description: _description,
            expDateEpoch: _expiryDate,
            barcodeId: _barcodeId,
            quantity: _quantity,
            price: _price,
            weights: _weights,
            manDateEpoch: _availableDate, //available date
            prebookCount: 0,
            itemState: Types.State.READY_FOR_SALE
        });

        manufacturedProduct[msg.sender][_pidHash] = manufProduct_;
        manufacturerInventor[msg.sender].push(manufProduct_);
        
        Types.productAvailableManuf memory _productAvailableManuf = Types.productAvailableManuf({
            id: msg.sender,
            productName: _prodName,
            productID: _pidHash,
            quantity: _quantity,
            price: _price,
            availableDate: _availableDate,
            weights: _weights,
            expDateEpoch: _expiryDate
        });

        sameproductLinkedWithManufacturer[_prodName].push(_productAvailableManuf); 

        emit ManufacturedProductAdded(
            _prodName,
            msg.sender,
            _barcodeId,
            _availableDate,
            _expiryDate,
            Types.State.READY_FOR_SALE
            );
        }
    }

    function getManufacturedProducts(string memory _productName)
        external
        view
        returns (Types.productAvailableManuf[] memory)
    {
        return sameproductLinkedWithManufacturer[_productName];
    }

    function getManufacturerProducts(address _manufAdd)
        external
        view
        returns (Types.manfItem[] memory)
    {
        return manufacturerInventor[_manufAdd];
    }

    function manufProductDetails(bytes32 _manfProductID)
        external
        view
        returns (Types.manfItem memory)
    {
        return manufacturedProduct[msg.sender][_manfProductID];
    }

    function getmanufProductDetail(address _manufacturerAdd, bytes32 _manfProductID)
        external
        view
        returns (Types.manfItem memory)
    {
        return manufacturedProduct[_manufacturerAdd][_manfProductID];
    }

     function manufProductName(bytes32 _manfProductID)
        external
        view
        returns (string memory)
    {
        return manufacturedProduct[msg.sender][_manfProductID].name;
    }

    function updateAProduct(
        string memory _prodName,
        bytes32 _pID,
        string memory _description,
        uint256 _expiryDate,
        uint256 _quantity,
        uint256 _price,
        uint256 _weights,
        uint256 _availableDate
    ) internal
    {   
        bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_prodName);
        Types.manfItem memory updatingProduct = manufacturedProduct[
            msg.sender
        ][_pidHash];
        updatingProduct.name = _prodName;
        updatingProduct.PId = _pidHash;
        updatingProduct.description = _description;
        updatingProduct.expDateEpoch = _expiryDate;
        updatingProduct.quantity = _quantity;
        updatingProduct.price = _price;
        updatingProduct.weights = _weights;
        updatingProduct.manDateEpoch = _availableDate;

        Types.manfItem[] storage products_ = manufacturerInventor[msg.sender];
        uint256 index = manufacturedProduct[msg.sender][_pID].ArrIndex;

        products_[index].name = _prodName;
        products_[index].PId = _pidHash;
        products_[index].description = _description;
        products_[index].expDateEpoch = _expiryDate;
        products_[index].quantity = _quantity;
        products_[index].price = _price;
        products_[index].weights = _weights;
        products_[index].manDateEpoch = _availableDate;

        emit ManufacturedProductUpdated(
            _prodName,
            msg.sender,
            _availableDate,
            _expiryDate,
            _pidHash
        );
    }    
}