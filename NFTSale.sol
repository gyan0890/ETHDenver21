pragma solidity >=0.4.21 <0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC721/ERC721Full.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC721/ERC721Mintable.sol";

contract HRC721 is ERC721Full, ERC721Mintable {
	//maps tokenIds to item indexes
	mapping(uint256 => uint256) private itemIndex;
	//sales
	// struct Sale {
	// 	//tight pack 256bits
	// 	uint128 price;
	// 	//end tight pack
    // }
	mapping(uint256 => uint256) private salePrice;
	
	constructor(string memory _name, string memory _symbol) ERC721Full(_name, _symbol) public {}

	function setSale(uint256 tokenId, uint256 price) public {
		address owner = ownerOf(tokenId);
        require(owner != address(0), "setSale: nonexistent token");
        require(owner == msg.sender, "setSale: msg.sender is not the owner of the token");
		salePrice[tokenId] = price;
	}

	function buyTokenOnSale(uint256 tokenId) public payable {
		uint256 price = salePrice[tokenId];
        require(price != 0, "buyToken: price equals 0");
        require(msg.value == price, "buyToken: price doesn't equal salePrice[tokenId]");
		address payable owner = address(uint160(ownerOf(tokenId)));
		approve(address(this), tokenId);
		salePrice[tokenId] = 0;
		_transferFrom(owner, msg.sender, tokenId);
        owner.transfer(msg.value);
	}

	function mintWithIndex(address to, uint256 index) public onlyMinter {
		uint256 tokenId = totalSupply() + 1;
		itemIndex[tokenId] = index;
        mint(to, tokenId);
	}

	function getItemIndex(uint256 tokenId) public view returns (uint256) {
		return itemIndex[tokenId];
	}

	function getSalePrice(uint256 tokenId) public view returns (uint256) {
		return salePrice[tokenId];
	}
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address payable public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(address payable _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address payable _newOwner) internal {
    require(_newOwner != address(0));
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}

/**
 * @title Destructible
 * @dev Base contract that can be destroyed by owner. All funds in contract will be sent to the owner.
 */
contract Destructible is Ownable {

  constructor() public payable { }

  /**
   * @dev Transfers the current balance to the owner and terminates the contract.
   */
  function destroy() onlyOwner public {
    selfdestruct(owner);
  }

  function destroyAndSend(address payable _recipient) onlyOwner public {
    selfdestruct(_recipient);
  }
}


contract NFTSale is Ownable, Pausable, Destructible {

    event Sent(address indexed payee, uint256 amount, uint256 balance);
    event Received(address indexed payer, uint tokenId, uint256 amount, uint256 balance);
    event Donated(address indexed charity, uint256 amount);

    /**
    * HRC721 - Harmony contract to create NFTs
    * currentPrice - Initial Sale price set by the contract owner
    * charityAddress - Org address chosen by the NFT creator
    */
    HRC721 public nftAddress;
    uint256 public currentPrice;
    address payable public charityAddress;

    /**
    * @dev Contract Constructor
    * @param _nftAddress address for the Harmongy non-fungible token contract 
    * @param _currentPrice initial sales price
    */
    constructor(address _nftAddress, uint256 _currentPrice,  address payable _charityAddress) public { 
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(_currentPrice > 0);
        nftAddress = HRC721(_nftAddress);
        currentPrice = _currentPrice;
        charityAddress = _charityAddress;
    }

    /**
     * @dev check the owner of a Token
     * @param _tokenId uint256 token representing an Object
     * Test function to check if the token address can be retrieved.
     */
    function getTokenSellerAddress(uint256 _tokenId) internal view returns(address) {
        address tokenSeller = nftAddress.ownerOf(_tokenId);
        return tokenSeller;
    }
    
    /**
    * @dev Purchase _tokenId
    * @param _tokenId uint256 token ID representing an Object
    * Sends the extra bid amount to the charity address.
    */
    function purchaseToken(uint256 _tokenId) public payable whenNotPaused {
        require(msg.sender != address(0) && msg.sender != address(this));
        require(msg.value >= currentPrice);
        require(nftAddress.ownerOf(_tokenId) != address(0));
        address tokenSeller = nftAddress.ownerOf(_tokenId);
        nftAddress.safeTransferFrom(tokenSeller, msg.sender, _tokenId);
        uint256 donation = uint256(msg.value) - currentPrice;
        if(donation > 0){
            sendToCharity(donation, charityAddress);
        }
        
        emit Received(msg.sender, _tokenId, msg.value, address(this).balance);
    }

    //Returning the current price for testing
    // function getCurrentPrice() public view returns(uint256){
    //     return currentPrice;
    // }

    /**
    * @dev send / withdraw _amount to _payee
    */
    function sendTo(address payable _payee) public payable onlyOwner {
        require(_payee != address(0) && _payee != address(this), "Payee address cannot be 0 or the contract");
        require(currentPrice > 0 && currentPrice <= address(this).balance, 
            "Current price needs to be greater than 0/Funds from this were already withdrawn");
        _payee.transfer(currentPrice);
        emit Sent(_payee, currentPrice, address(this).balance);
    }    

    /**
    * @dev Updates _currentPrice
    * @dev Throws if _currentPrice is zero
    */
    function setCurrentPrice(uint256 _currentPrice) public onlyOwner {
        require(_currentPrice > 0);
        currentPrice = _currentPrice;
    }  
    
    /**
    * @dev sendToCharity Donate amount to the charity
    * @param _donation: Amount to be donated , _charity: Chosen charity org's address
    */
    function sendToCharity(uint256 _donation, address payable _charity) public payable {
        require(_charity != address(this));
        require(_donation > 0);
        _charity.transfer(_donation);
        emit Donated(_charity, _donation);
    }

}
