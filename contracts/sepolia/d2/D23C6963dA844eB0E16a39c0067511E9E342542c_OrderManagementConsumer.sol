/**
 *Submitted for verification at Etherscan.io on 2023-06-13
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
        PRODUCED,   //0
        PROCESSED,  //1
        ready_to_ship,  //2
        pre_bookable,   //3
        PICKUP,     //4
        SHIPMENT_RELEASED,  //5 
        RECEIVED_SHIPMENT,  //6
        DELIVERED,  //7
        READY_FOR_SALE, //8
        SOLD    //9
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
        // uint256 ArrInd_;
        address id_; // account Id of the user
        // bool itemExists_;
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
    mapping(address => Types.Stakeholder) stakeholders;
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

// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/Supplier.sol


pragma solidity ^0.8.15;




contract Supplier {

    Types.SupplierWithMaterialID[] internal supplierWithMaterialID;
    mapping(bytes32 => Types.SupplierWithMaterialID[]) public supplierPrices;
    // mapping(address => mapping(bytes32 => Types.SupplierWithMaterialID[])) public supplierPrices2;
    

    mapping(address =>mapping(bytes32 => Types.Item)) public supplyItems;
    mapping(address => Types.Item[]) public supplyItemsInventory;
    mapping(address =>mapping(bytes32 => Types.manfItem)) public supplyManufItems;
    mapping(address => Types.manfItem[]) public supplyManufItemsInventory;
    event supplierSet(
        address id_, // account Id of the user
        bytes32 productid_,
        uint256 supplyprice_,
        uint256 requestCreationTime_
    );
 
function supplierSetMaterialIDandPrice(bytes32 Itemid_, uint256 supplyprice_) public {
    Types.SupplierWithMaterialID memory supplierMaterialID_ = Types.SupplierWithMaterialID({
        // ArrInd_: supplierPrices[Itemid_].length, 
        id_: msg.sender,
        // itemExists_ : true,
        itemId_: Itemid_,
        supplyprice_: supplyprice_
    });

        supplierWithMaterialID.push(supplierMaterialID_);
        supplierPrices[Itemid_].push(supplierMaterialID_);
        emit supplierSet(msg.sender, Itemid_, supplyprice_, block.timestamp);

    // Types.SupplierWithMaterialID[] storage suppliers = supplierPrices[Itemid_];
    // uint256 index = supplier.ArrInd_;
    
    // if (supplierPrices[Itemid_].id_ == address(msg.sender)) {
    //     supplierWithMaterialID.push(supplierMaterialID_);
    //     supplierPrices[Itemid_].push(supplierMaterialID_);
    // }
    
    emit supplierSet(msg.sender, Itemid_, supplyprice_, block.timestamp);
}
}

// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/Inventory.sol


pragma solidity ^0.8.15;




contract Inventroy {
    
    StakeHolderRegistration registration;
    GenratesAndConversion genCn;
    
    constructor(GenratesAndConversion _genCn, StakeHolderRegistration _registration){
        genCn = _genCn;
        registration = _registration;
    }

    mapping(address => Types.Item[]) internal producerInventor;
    mapping(address => mapping(bytes32 => Types.Item)) internal rawMaterials; //mapping change public to normal
    mapping(address => Types.manfItem[]) internal productInventory;
    mapping(address => mapping(bytes32 => Types.manfItem))
        internal manufacturedProduct;
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
        uint256 _availableDate,
        uint256 _expiryDate,
        uint256 _price
    ) public {
        bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_materialname); //creates unique key using product name
        
        if(rawMaterials[msg.sender][_pidHash].PId == _pidHash){
            updateRawMaterial(_pidHash, rawMaterials[msg.sender][_pidHash].Quantity+_quantity,_availableDate, _expiryDate, _price);
        } else {

        Types.Item memory newRawMaterial = Types.Item({
            ArrayIndex: producerInventor[msg.sender].length,
            PId: _pidHash,
            MaterialName: _materialname,
            Quantity: _quantity,
            AvailableDate: _availableDate,
            ExpiryDate: _expiryDate,
            Price: _price,
            IsAdded: true,
            itemState: Types.State.PRODUCED,
            prebookCount: 0
        });

        rawMaterials[msg.sender][_pidHash] = newRawMaterial;
        addItemsInProducerInventory(rawMaterials[msg.sender][_pidHash]);
    
        emit AddedInInventory(
            _pidHash,
            _materialname,
            _quantity,
            _availableDate,
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
        Types.Item storage updateMaterial = rawMaterials[msg.sender][_pid];
        
        updateMaterial.AvailableDate = _availableDate;
        updateMaterial.ExpiryDate = _expiryDate;
        updateMaterial.Quantity = _quantity;
        updateMaterial.Price = _price;

        //logic implemented here by adding ArrayIndex
        Types.Item[] storage products = producerInventor[msg.sender];
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
    function addItemsInProducerInventory(Types.Item storage _newRawMaterial)
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

    // function getProductDetails(bytes32 _prodId)
    //     public
    //     view
    //     returns (Types.Item memory)
    // {
    //     return rawMaterials[msg.sender][_prodId];
    // }

    function getAddedMaterialDetails(address _producerID, bytes32 _productID)
        external
        view
        returns (Types.Item memory)
    {
        return rawMaterials[_producerID][_productID];
    }

    //forchecking Inventory producer can check Inventroy is added or not by passing product name.
    // function IsAddedInInventory(string memory _materialName, bytes32 _pid)
    //     public
    //     view
    //     returns (bool)
    // {
    //     // bytes32 hash = keccak256(abi.encodePacked(_materialname));
    //     return (keccak256(
    //         abi.encodePacked((rawMaterials[msg.sender][_pid].MaterialName))
    //     ) == keccak256(abi.encodePacked((_materialName))));
    // }

    //Manufacturer Product Adding

    function addAProduct(
        string memory _prodName,
        string memory _description,
        uint256 _expiryDate,
        string memory _barcodeId,
        uint256 _quantity,
        uint256 _price,
        uint256 _weights,
        uint256 _availableDate
    ) public // productNotExists(_)
    // onlyManufacturer
    {
        bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_prodName);
          if(_pidHash == manufacturedProduct[msg.sender][_pidHash].PId){
            updateAProduct(_prodName, _pidHash, _description, _expiryDate, manufacturedProduct[msg.sender][_pidHash].quantity+=_quantity, _price, _weights, _availableDate);
        }
        else    {
        
        Types.manfItem memory manufProduct_ = Types.manfItem({
            ArrIndex: productInventory[msg.sender].length,
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
            itemState: Types.State.ready_to_ship
        });

        manufacturedProduct[msg.sender][_pidHash] = manufProduct_;
        productInventory[msg.sender].push(manufProduct_);
        
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
            Types.State.ready_to_ship
            );
        }
    }

    // getManufacturedProducts
    function getManufacturedProductsByProductName(string memory _productName)
        external
        view
        returns (Types.productAvailableManuf[] memory)
    {
        return sameproductLinkedWithManufacturer[_productName];
    }


    function getManufacturerProducts(address _manufAdd)
        public
        view
        returns (Types.manfItem[] memory)
    {
        return productInventory[_manufAdd];
    }

    function getmanufEachProductDetails(address _manufAddress, bytes32 _manfProductID)
        external
        view
        returns (Types.manfItem memory)
    {
        return manufacturedProduct[_manufAddress][_manfProductID];
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
    ) internal // productNotExists(_)
    // onlyManufacturer
    {
        bytes32 _pidHash = genCn.genrateUniqueIDByProductName(_prodName);
        Types.manfItem storage updatingProduct = manufacturedProduct[
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

        Types.manfItem[] storage products_ = productInventory[msg.sender];
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
// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/OrderManagementDistributor.sol


pragma solidity ^0.8.15;




contract OrderManagementDistributor is Supplier {

    GenratesAndConversion public genCn;
    StakeHolderRegistration public registration;
    Inventroy public inventory;

    constructor(
        GenratesAndConversion _genCn,
        StakeHolderRegistration _registration,
        Inventroy _inventory
    ) {
       genCn = _genCn;
       registration = _registration;
       inventory = _inventory;
    }


    mapping(address => Types.ProductHistory[]) internal productHistory;
    mapping(address => Types.PurchaseOrderHistoryD) internal purchaseproductsHistory;

    mapping(string => Types.productAvailableManuf[]) internal sameproductLinkedWithDistributors;


    event ReadyForShip(bytes32 productId, uint256 quantity,Types.State _itemState);    //User Before purchase request creation.
    event PickedUp(address producerID, bytes32 prodId, uint256 quantity, Types.State _itemState);  //supplier after purchase request at the manufacturer end
    event ShipmentReleased(bytes32 productId, Types.State _itemState);
    event ShipmentReceived(bytes32 productId, Types.State _itemState);  //manufacturer after order(material) received
    event Sold(bytes32 productId, Types.State _itemState);  //when user created the request
    event MaterialDelivered(bytes32 productId, Types.State _itemState);    //
    event ProductPurchased(
        address _producerId,
        bytes32 _productId,
        uint256 _quantity,
        uint256 _orderTime,
        Types.State _itemState
    );
    event newevent(Types.manfItem);

    
     //creates a material request through the function
    function createRequest(
        bytes32 materialId_, //prod unique ID
        uint256 quantity_,
        uint256 availableDate_
    ) external view  returns (Types.SupplierWithMaterialID[] memory) {
        
        return supplierPrices[materialId_];
    }


    //Distributors calls this function
    function PurchaseProduct(
        address _manufactureId,
        address _supplierrId,
        bytes32 _productId,
        uint256 _quantity
    )public _isDisributor(msg.sender) {

        Types.manfItem memory _purchaseProduct = inventory.getmanufEachProductDetails(
            _manufactureId,
            _productId
        );

        emit newevent(_purchaseProduct);

        require(
            _purchaseProduct.quantity >= _quantity,
            "Insufficient inventory"
        );

        Types.manfItem memory _newProduct = Types.manfItem({
            ArrIndex: supplyManufItemsInventory[msg.sender].length,
            name: _purchaseProduct.name,
            PId: _purchaseProduct.PId,
            description: _purchaseProduct.description,
            expDateEpoch: _purchaseProduct.expDateEpoch,
            barcodeId: _purchaseProduct.barcodeId,
            quantity: _quantity,
            price: _purchaseProduct.price,
            weights: _purchaseProduct.weights,
            manDateEpoch: _purchaseProduct.manDateEpoch, //available date
            prebookCount: _quantity,
            itemState: Types.State.SOLD
        });

        // supplyManufItems[_supplierrId][_purchaseProduct.PId] = _newProduct;
        // supplyManufItemsInventory[_supplierrId].push(_newProduct);

        Types.productAvailableManuf memory _productAvailableManuf = Types.productAvailableManuf({
            id: msg.sender,
            productName: _purchaseProduct.name,
            productID: _purchaseProduct.PId,
            quantity: _quantity,
            price: _purchaseProduct.price,
            availableDate: _purchaseProduct.manDateEpoch,
            weights: _purchaseProduct.weights,
            expDateEpoch: _purchaseProduct.expDateEpoch
        });

        sameproductLinkedWithDistributors[_purchaseProduct.name].push(_productAvailableManuf); 

        Types.PurchaseOrderHistoryD memory purchaseOrderHistory_ = Types
            .PurchaseOrderHistoryD({
                distributorId: msg.sender,
                manufacturerid: _manufactureId,
                supplierId: _supplierrId,
                product: _newProduct,
                orderTime: block.timestamp
            });

        Types.ProductHistory memory newProd_ = Types.ProductHistory({
            distributor: purchaseOrderHistory_
        });


        if (
            registration.getStakeHolderDetails(msg.sender).role ==
            Types.StakeHolder.distributors
        ) {
            productHistory[msg.sender].push(newProd_);
        }

        // Emiting event
        emit ProductPurchased(
            _manufactureId,
            _productId,
            _quantity,
            block.timestamp,
            Types.State.pre_bookable
        );
    }

    //Accessible by - manufacturer
    function markProductReadyForShip(address _manufacturerAdd, bytes32 _manfProductID, uint256 _quantity)
        public _isManufacturer(_manufacturerAdd)
    {
        Types.manfItem memory product_ = inventory.getmanufEachProductDetails(
            _manufacturerAdd,
            _manfProductID
        );
        product_.itemState = Types.State.ready_to_ship;
        emit ReadyForShip(_manfProductID, _quantity, product_.itemState);
    }

    //Accessible by - supplier
    function markProductPickedUp(address _suuplierOwnAddress, address _manufacturerID, bytes32 _prodId, uint256 _quantity)
        public _isSupplier(_suuplierOwnAddress)
    {
        Types.manfItem memory product_ = inventory.getmanufEachProductDetails(
            _manufacturerID,
            _prodId
        );
        product_.itemState = Types.State.PICKUP;
        //after picking up product has been came in the supplier Inventory
         Types.manfItem memory _newProduct = Types.manfItem({
            ArrIndex: supplyManufItemsInventory[msg.sender].length,
            name: product_.name,
            PId: product_.PId,
            description: product_.description,
            expDateEpoch: product_.expDateEpoch,
            barcodeId: product_.barcodeId,
            quantity: _quantity,
            price: product_.price,
            weights: product_.weights,
            manDateEpoch: product_.manDateEpoch, //available date
            prebookCount: _quantity,
            itemState: Types.State.SOLD
        });
        emit newevent(_newProduct);

        supplyManufItems[_suuplierOwnAddress][_prodId] = _newProduct;
        supplyManufItemsInventory[_suuplierOwnAddress].push(_newProduct);
        emit PickedUp(_manufacturerID, _prodId, _quantity, product_.itemState);
    }

    //Accessible by - Manufacturer
    function markProductShipmentReleased(address _manufacturerID, bytes32 _prodId, uint256 _quantity)
        public _isManufacturer(_manufacturerID) 
    {
        Types.manfItem memory product_ = inventory.getmanufEachProductDetails(
            _manufacturerID,
            _prodId
        );

        product_.quantity -= _quantity;
        product_.itemState = Types.State.SHIPMENT_RELEASED;
        
        emit ShipmentReleased(_prodId, product_.itemState);
    }

    //Accessible by - supplier
    function markProductDelivered(
        address _supplierOwnAddress,
        address _distributorID,
        bytes32 _prodId,
        uint256 _prodQuantity
    ) public _isSupplier(_supplierOwnAddress) {

        Types.manfItem memory fetchProduct = supplyManufItems[_supplierOwnAddress][_prodId];
        emit newevent(fetchProduct);

        supplyManufItems[_distributorID][_prodId] = (fetchProduct);
        supplyManufItemsInventory[_distributorID].push(fetchProduct);

        fetchProduct.quantity -= _prodQuantity;
        fetchProduct.itemState = Types.State.DELIVERED;

        // emit MaterialDelivered(_prodId, Types.State.DELIVERED);
    }


    //Accessible by -Distributors
    function markProductsRecieved(address _distributorID, bytes32 _prodId)
        public _isDisributor(_distributorID)
    {
        Types.manfItem memory _newMaterial = supplyManufItems[_distributorID][_prodId];  
        
        _newMaterial.itemState = Types.State.RECEIVED_SHIPMENT;

        emit ShipmentReceived(_prodId, Types.State.RECEIVED_SHIPMENT);
    }

    /*________________________________________________________________________*/
    
    function getDistributorProductsDetails(address _distributorID, bytes32 _prodId) public view returns(Types.manfItem memory){
        Types.manfItem memory _newMaterial = supplyManufItems[_distributorID][_prodId];
        return _newMaterial;
    }

    //@supplier and @Maufacturer can checks raw materials from producer Inventory.
    function getDistributorProducts(address _distributorId) public view returns(Types.manfItem[] memory){
        return supplyManufItemsInventory[_distributorId];
    } 

    // onlyManufacturer()
    function getProductPurchaseHistory() public view returns(Types.ProductHistory[] memory){
        return productHistory[msg.sender];
    }

    function getDistributorProductsByName(string memory _productName)
        external
        view
        returns (Types.productAvailableManuf[] memory)
    {
        return sameproductLinkedWithDistributors[_productName];
    }
    
    /*_________________________________________________________________________*/

    
    function isManufacturer(address _Maddress) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_Maddress).role ==
            Types.StakeHolder.ManuFacturer;
    }

    function isDistributor(address _Daddress) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_Daddress).role ==
            Types.StakeHolder.distributors;
    }

    function isSupplier(address _Saddress) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_Saddress).role ==
            Types.StakeHolder.supplier;
    }

    
    modifier _isManufacturer(address _manfAddr) {
      require(registration.getStakeHolderDetails(_manfAddr).role ==
            Types.StakeHolder.ManuFacturer, "manufcaturer not registered yet or only manufacturer can calls this function");
      _;
    }

    modifier _isDisributor(address _prodAddr) {
      require(registration.getStakeHolderDetails(_prodAddr).role ==
            Types.StakeHolder.distributors, "Distrubtor have't registered yet or only distributor have permission to call this function.");
      _;
    }

    modifier _isSupplier(address _suppAddr) {
      require(registration.getStakeHolderDetails(_suppAddr).role ==
            Types.StakeHolder.supplier, "supplier not registered yet or only supplier can calls this function");
      _;
    }
}

// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/OrderManagementRetailer.sol


pragma solidity ^0.8.15;





contract OrderManagementRetailer is Supplier {

    GenratesAndConversion public genCn;
    StakeHolderRegistration public registration;
    OrderManagementDistributor public omdistr;
    Inventroy public inventory;

    constructor(
        GenratesAndConversion _genCn,
        StakeHolderRegistration _registration,
        Inventroy _inventory,
        OrderManagementDistributor _omdistr
    ) {
       genCn = _genCn;
       registration = _registration;
       inventory = _inventory;
       omdistr = _omdistr;
    }

    mapping(address => Types.ProductHistoryRetail[]) internal productHistoryRetail;
    mapping(address => Types.PurchaseOrderHistoryR) internal purchaseProductsHistoryRetailer;
    mapping(string => Types.productAvailableManuf[]) internal sameProductLinkedWithRetailer;

    event ReadyForShip(bytes32 productId, uint256 quantity,Types.State _itemState);    //User Before purchase request creation.
    event PickedUp(address producerID, bytes32 prodId, uint256 quantity, Types.State _itemState);  //supplier after purchase request at the manufacturer end
    event ShipmentReleased(bytes32 productId, Types.State _itemState);
    event ShipmentReceived(bytes32 productId, Types.State _itemState);  //manufacturer after order(material) received
    event Sold(bytes32 productId, Types.State _itemState);  //when user created the request
    event MaterialDelivered(bytes32 productId, Types.State _itemState);    //
    event ProductPurchased(
        address _producerId,
        bytes32 _productId,
        uint256 _quantity,
        uint256 _orderTime,
        Types.State _itemState
    );
    event newevent(Types.manfItem);

   
    //creates a material request through the function
    function createRequest(
        bytes32 materialId_, //prod unique ID
        uint256 quantity_,
        uint256 availableDate_
    ) external view returns (Types.SupplierWithMaterialID[] memory) {
        return supplierPrices[materialId_];
    }

    //retailers calls this function
    function PurchaseProductByRetailer(
        address _distributorId,
        address _supplierrId,
        bytes32 _productId,
        uint256 _quantity
    )public _isRetailer(_distributorId) {

        Types.manfItem memory _purchaseProduct;
         
        // if(registration.getStakeHolderDetails(_distributorId).role == Types.StakeHolder.ManuFacturer){
        //     Types.manfItem memory _purchaseProductM = inventory.getmanufProductDetail(
        //     _distributorId,
        //     _productId
        // );
        // _purchaseProduct = _purchaseProductM;
        // }
        // else 
        if(registration.getStakeHolderDetails(_distributorId).role == Types.StakeHolder.distributors){
              Types.manfItem memory _purchaseProductD = omdistr.getDistributorProductsDetails(
            _distributorId,
            _productId
        );
        _purchaseProduct = _purchaseProductD;
        emit newevent(_purchaseProduct);
        }

        require(
            _purchaseProduct.quantity >= _quantity, 
            "Insufficient inventory"
        );

        Types.manfItem memory _newProduct = Types.manfItem({
            ArrIndex: supplyManufItemsInventory[msg.sender].length,
            name: _purchaseProduct.name,
            PId: _purchaseProduct.PId,
            description: _purchaseProduct.description,
            expDateEpoch: _purchaseProduct.expDateEpoch,
            barcodeId: _purchaseProduct.barcodeId,
            quantity: _quantity,
            price: _purchaseProduct.price,
            weights: _purchaseProduct.weights,
            manDateEpoch: _purchaseProduct.manDateEpoch, //available date
            prebookCount: _quantity,
            itemState: Types.State.SOLD
        });
    
        // supplyManufItems[_supplierrId][_purchaseProduct.PId] = _newProduct;
        // supplyManufItemsInventory[_supplierrId].push(_newProduct);

        Types.productAvailableManuf memory _productAvailableManuf = Types.productAvailableManuf({
            id: msg.sender,
            productName: _purchaseProduct.name,
            productID: _purchaseProduct.PId,
            quantity: _quantity,
            price: _purchaseProduct.price,
            availableDate: _purchaseProduct.manDateEpoch,
            weights: _purchaseProduct.weights,
            expDateEpoch: _purchaseProduct.expDateEpoch
        });

        sameProductLinkedWithRetailer[_purchaseProduct.name].push(_productAvailableManuf); 
        
        Types.PurchaseOrderHistoryR memory purchaseOrderHistory_ = Types.PurchaseOrderHistoryR({
                retailerId: msg.sender,
                distributorId: _distributorId,
                supplierId: _supplierrId,
                product: _newProduct,
                orderTime: block.timestamp
            });

        Types.ProductHistoryRetail memory newProd_ = Types.ProductHistoryRetail({
            retailer: purchaseOrderHistory_
        });

        if (
            registration.getStakeHolderDetails(msg.sender).role ==
            Types.StakeHolder.retailers
        ) {
            productHistoryRetail[msg.sender].push(newProd_);
        }

        // Emiting event
        emit ProductPurchased(
            _distributorId,
            _productId,
            _quantity,
            block.timestamp,
            Types.State.pre_bookable
        );
    }

    //Accessible by - distributor
    function markProductReadyForShip(address _distributorId, bytes32 _manfProductID, uint256 _quantity)
        public _isDisributor(_distributorId)
    {
        Types.manfItem memory product_ = inventory.getmanufEachProductDetails(
            _distributorId,
            _manfProductID
        );
        product_.itemState = Types.State.ready_to_ship;
        emit ReadyForShip(_manfProductID, _quantity, product_.itemState);
    }

    //Accessible by - supplier
    function markProductPickedUpBySupplier(address _suuplierOwnAddress, address _DistributorID, bytes32 _prodId, uint256 _quantity)
        public
    {
        Types.manfItem memory product_ = inventory.getmanufEachProductDetails(
            _DistributorID,
            _prodId
        );
         product_.itemState = Types.State.PICKUP;

        //after picking up product has been came in the supplier Inventory
         Types.manfItem memory _newProduct = Types.manfItem({
            ArrIndex: supplyManufItemsInventory[msg.sender].length,
            name: product_.name,
            PId: product_.PId,
            description: product_.description,
            expDateEpoch: product_.expDateEpoch,
            barcodeId: product_.barcodeId,
            quantity: _quantity,
            price: product_.price,
            weights: product_.weights,
            manDateEpoch: product_.manDateEpoch, //available date
            prebookCount: _quantity,
            itemState: Types.State.SOLD
        });
        emit newevent(_newProduct);

        supplyManufItems[_suuplierOwnAddress][_prodId] = _newProduct;
        supplyManufItemsInventory[_suuplierOwnAddress].push(_newProduct);
        emit PickedUp(_DistributorID, _prodId, _quantity, product_.itemState);
    }

    //Accessible by - Distributor
    function markProductShipmentReleased(address _DistributorID, bytes32 _prodId, uint256 _quantity)
        public _isDisributor(_DistributorID)
    {
        Types.manfItem memory product_ = inventory.getmanufEachProductDetails(
            _DistributorID,
            _prodId
        );

        product_.quantity -= _quantity;
        product_.itemState = Types.State.SHIPMENT_RELEASED;

        emit ShipmentReleased(_prodId, product_.itemState);
    }

    //Accessible by - supplier
    function markProductDeliveredBySupplier(
        address _supplierOwnAddress,
        address _retailerID,
        bytes32 _prodId,
        uint256 _prodQuantity
    ) public _isSupplier(_supplierOwnAddress) {

        Types.manfItem memory fetchProduct = supplyManufItems[_supplierOwnAddress][_prodId];
        emit newevent(fetchProduct);

        supplyManufItems[_retailerID][_prodId] = (fetchProduct);
        supplyManufItemsInventory[_retailerID].push(fetchProduct);

        fetchProduct.quantity -= _prodQuantity;
        fetchProduct.itemState = Types.State.DELIVERED;
        
        emit MaterialDelivered(_prodId, fetchProduct.itemState);
    }


    //Accessible by -retailer
    function markProductRecievedByRetail(address _retailerID, bytes32 _prodId)
        public _isRetailer(_retailerID)
    {
        Types.manfItem memory _newMaterial = supplyManufItems[_retailerID][_prodId];  
        _newMaterial.itemState = Types.State.RECEIVED_SHIPMENT;
        emit ShipmentReceived(_prodId, Types.State.RECEIVED_SHIPMENT);
    }
    /*___________________________________________________*/
     
    function getRetailerProductsDetails(address _retailerID, bytes32 _prodId) public view returns(Types.manfItem memory){
        Types.manfItem memory _newMaterial = supplyManufItems[_retailerID][_prodId];
        return _newMaterial;
    }

    //@supplier and @retailer can checks raw materials from producer Inventory.
    function getRetailerProducts(address _retailerId) public view returns(Types.manfItem[] memory){
        return supplyManufItemsInventory[_retailerId];
    } 

    // onlyManufacturer()
    function getProductPurchaseHistory() public view returns(Types.ProductHistoryRetail[] memory){
        return  productHistoryRetail[msg.sender];
    }

    function getRetailerProductsByName(string memory _productName)
        external
        view
        returns (Types.productAvailableManuf[] memory)
    {
        return sameProductLinkedWithRetailer[_productName];
    }

    /*---------------------------------------------------*/

    function isDistributor(address _Daddress) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_Daddress).role ==
            Types.StakeHolder.distributors;
    }

    function isRetailer(address _retailAddr) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_retailAddr).role ==
            Types.StakeHolder.retailers;
    }

    function isSupplier(address _Saddress) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_Saddress).role ==
            Types.StakeHolder.supplier;
    }

    /*---------------------------------------------------*/
    
   
    modifier _isDisributor(address _distAddr) {
      require(registration.getStakeHolderDetails(_distAddr).role ==
            Types.StakeHolder.distributors, "Distrubtor have't registered yet or only distributor have permission to call this function.");
      _;
    }

     modifier _isRetailer(address _retailAddr) {
      require(registration.getStakeHolderDetails(_retailAddr).role ==
            Types.StakeHolder.retailers, "retailers not registered yet or only retailers can calls this function");
      _;
    }

    modifier _isSupplier(address _suppAddr) {
      require(registration.getStakeHolderDetails(_suppAddr).role ==
            Types.StakeHolder.supplier, "supplier not registered yet or only supplier can calls this function");
      _;
    }

    /*_____________________________________________________*/
    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

}
// File: Amira Code v3/Optimized Amira Code v2 (2)/Optimized Amira Code v2/OrderManagementConsumer.sol


pragma solidity ^0.8.15;





contract OrderManagementConsumer is Supplier {

    GenratesAndConversion public genCn;
    StakeHolderRegistration public registration;
    OrderManagementRetailer public omretlier;
    Inventroy public inventory;

    constructor(
        GenratesAndConversion _genCn,
        StakeHolderRegistration _registration,
        OrderManagementRetailer _omretlier,
        Inventroy _inventory
    ) {
       
       genCn = _genCn;
       registration = _registration;
       omretlier = _omretlier;
       inventory = _inventory;
    }

    // mapping(address => Types.MaterialHistory[]) internal materialHistory;
    mapping(address => Types.PurchaseOrderHistoryM) internal purchasematerialsHistory;

    mapping(address => uint256) internal supllierTotalprice;

  event ReadyForShip(bytes32 productId, uint256 quantity,Types.State _itemState);    //User Before purchase request creation.
    event PickedUp(address producerID, bytes32 prodId, uint256 quantity, Types.State _itemState);  //supplier after purchase request at the manufacturer end
    event ShipmentReleased(bytes32 productId, Types.State _itemState);
    event ShipmentReceived(bytes32 productId, Types.State _itemState);  //manufacturer after order(material) received
    event Sold(bytes32 productId, Types.State _itemState);  //when user created the request
    event MaterialDelivered(bytes32 productId, Types.State _itemState);    //
    event AgreedWithData(
            address _consumerAddress,
            uint256 _supplyAmount,
            uint256 _deliveryDate
            );

    event ProductPurchasedRequest(
        address _producerId,
        bytes32 _productId,
        uint256 _quantity,
        uint256 _orderTime,
        Types.State _itemState,
        uint256 _totalAmount
    );
    event newevent(Types.manfItem);
  
    /*@consumer creating request for product*/
    //creates a material request through the function
    function createRequest (
        string memory _materialName, //prod unique ID
        uint256 _quantity,
        uint256 _deliveryDate
    ) external view returns (Types.SupplierWithMaterialID[] memory) {     
        bytes32 materialId_ = genCn.genrateUniqueIDByProductName(_materialName);   
        return supplierPrices[materialId_];
    }


    //Consumer calls this function
    function PurchaseProduct(
        address _retailerId,
        address _supplierId,
        bytes32 _ItemId,
        uint256 _quantity
    ) public {

        Types.manfItem memory _purchaseProduct = omretlier.getRetailerProductsDetails(
            _retailerId,
            _ItemId
        );

        //first fetch the product from the retailer Inventory.
        require(
            _purchaseProduct.quantity >= _quantity,
            "Insufficient inventory"
        );
        
        Types.manfItem memory _newProduct = Types.manfItem({
            ArrIndex: supplyManufItemsInventory[msg.sender].length,
            name: _purchaseProduct.name,
            PId: _purchaseProduct.PId,
            description: _purchaseProduct.description,
            expDateEpoch: _purchaseProduct.expDateEpoch,
            barcodeId: _purchaseProduct.barcodeId,
            quantity: _quantity,
            price: _purchaseProduct.price,
            weights: _purchaseProduct.weights,
            manDateEpoch: _purchaseProduct.manDateEpoch, //available date
            prebookCount: _quantity,
            itemState: Types.State.SOLD
        });

        // supplyManufItems[_supplierId][_purchaseProduct.PId] = _newProduct;
        // supplyManufItemsInventory[_supplierId].push(_newProduct);

        // uint256 supplierPrice = supplierPrices[_ItemId].supplyprice_;
        uint256 payableAmount = (_purchaseProduct.price * _quantity);
        
        // Emiting event
        emit ProductPurchasedRequest(
            _retailerId,
            _ItemId,
            _quantity,
            block.timestamp,
            Types.State.SOLD,
            payableAmount
        );
    }

    //@Supplier calls this function 
    function supplierGenratedAgreedwithDate(address _consumerAddress, address _retailerAddress, bytes32 _manfProductID, uint256 _supplyTotalAmount, uint _deliveryDate) public {
    
        Types.manfItem memory product_ = omretlier.getRetailerProductsDetails(
            _retailerAddress,
            _manfProductID
        );

        product_.itemState = Types.State.PROCESSED;
        supllierTotalprice[_consumerAddress] = _supplyTotalAmount;
        
        emit AgreedWithData(
                _consumerAddress,
                _supplyTotalAmount,
                _deliveryDate
            );
    }

    // @consumer after agreed 
    function OrderGenarted( 
        address payable _retailerId,
        address _supplierId,
        bytes32 _ItemId,
        uint256 _quantity)
         public payable {
        
        Types.manfItem memory _purchaseProduct = omretlier.getRetailerProductsDetails(
            _retailerId,
            _ItemId
        );

         uint256 payableAmount = (_purchaseProduct.price * _quantity);
         uint256 supplyTotalAmount = supllierTotalprice[_supplierId]; 

        // Transfer money to farmer 
        _retailerId.transfer(payableAmount+supplyTotalAmount);
    }


    //Accessible by - retailer
    function markMaterialReadyForShip(bytes32 _prodId, uint256 _quantity) public
    {
        Types.manfItem memory product_ = omretlier.getRetailerProductsDetails(
            msg.sender,
            _prodId
        );
        product_.itemState = Types.State.ready_to_ship;
        emit ReadyForShip(_prodId, _quantity, product_.itemState);
    }

    //Accessible by - supplier
    function markMaterialReadyPickedUp(address _supplierOwnAddress, address _retailerID, bytes32 _prodId, uint256 _quantity)
        public
    {
        Types.manfItem memory product_ = omretlier.getRetailerProductsDetails(
            _retailerID,
            _prodId
        );
        product_.itemState = Types.State.PICKUP;

        //after picking up product has been came in the supplier Inventory
         Types.manfItem memory _newProduct = Types.manfItem({
            ArrIndex: supplyManufItemsInventory[msg.sender].length,
            name: product_.name,
            PId: product_.PId,
            description: product_.description,
            expDateEpoch: product_.expDateEpoch,
            barcodeId: product_.barcodeId,
            quantity: _quantity,
            price: product_.price,
            weights: product_.weights,
            manDateEpoch: product_.manDateEpoch, //available date
            prebookCount: _quantity,
            itemState: Types.State.SOLD
        });
        emit newevent(_newProduct);

        supplyManufItems[_supplierOwnAddress][_prodId] = _newProduct;
        supplyManufItemsInventory[_supplierOwnAddress].push(_newProduct);
        emit PickedUp(_retailerID, _prodId, _quantity, product_.itemState);
    }

     //Accessible by - retailer
    function markProductShipmentReleased(address _retailerID, bytes32 _prodId, uint256 _quantity)
        public _isRetailer(_retailerID)
    {
        Types.manfItem memory product_ = inventory.getmanufEachProductDetails(
            _retailerID,
            _prodId
        );

        product_.quantity -= _quantity;
        product_.itemState = Types.State.SHIPMENT_RELEASED;

        emit ShipmentReleased(_prodId, product_.itemState);
    }

    //Accessible by - supplier/
    function markMaterialDelivered(
        address _consumerAddress,
        address _retailerID,
        bytes32 _prodId,
        uint256 _matQuantity
    ) public _isConsumer(_consumerAddress) {

        Types.manfItem memory fetchProduct = supplyManufItems[_retailerID][_prodId];
        emit newevent(fetchProduct);

        supplyManufItems[_retailerID][_prodId] = (fetchProduct);
        supplyManufItemsInventory[_retailerID].push(fetchProduct);

        fetchProduct.itemState = Types.State.DELIVERED;
        fetchProduct.quantity -= _matQuantity;
        
        emit MaterialDelivered(_prodId, fetchProduct.itemState);
    }

    //Accessible by -consumer
    function markMaterialsRecieved(address _consumerAdd, address _retailerID, bytes32 _prodId)
        public _isConsumer(_consumerAdd)
    {
        Types.manfItem memory _newMaterial = supplyManufItems[_retailerID][_prodId];
        
        _newMaterial.itemState = Types.State.RECEIVED_SHIPMENT;
        emit ShipmentReceived(_prodId, Types.State.RECEIVED_SHIPMENT);
    }
    /*________________________________________________________________________*/
    
    //@supplier and @Maufacturer can checks raw materials from producer Inventory.
    function getConsumerProducts(address _Caddress) public _isConsumer(_Caddress) view returns(Types.Item[] memory){
        return supplyItemsInventory[_Caddress];
    } 

    /*_________________________________________________________________________*/

    
    function isRetailer(address _retailAddr) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_retailAddr).role ==
            Types.StakeHolder.retailers;
    }

    function isConsumer(address _Caddress) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_Caddress).role ==
            Types.StakeHolder.consumer;
    }

    function isSupplier(address _Saddress) public view returns (bool) {
        return
            registration.getStakeHolderDetails(_Saddress).role ==
            Types.StakeHolder.supplier;
    }

    /*---------------------------------------------------*/
    
   
     modifier _isRetailer(address _retailAddr) {
      require(registration.getStakeHolderDetails(_retailAddr).role ==
            Types.StakeHolder.retailers, "retailers not registered yet or only retailers can calls this function");
      _;
    }

     modifier _isConsumer(address _distAddr) {
      require(registration.getStakeHolderDetails(_distAddr).role ==
            Types.StakeHolder.consumer, "consumer have't registered yet or only consumer have permission to call this function.");
      _;
    }

    modifier _isSupplier(address _suppAddr) {
      require(registration.getStakeHolderDetails(_suppAddr).role ==
            Types.StakeHolder.supplier, "supplier not registered yet or only supplier can calls this function");
      _;
    }

}