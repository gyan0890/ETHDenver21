pragma solidity >=0.4.21 <0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC721/ERC721Full.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC721/ERC721Mintable.sol";

contract HRC721 is ERC721Full, ERC721Mintable {
	//maps tokenIds to item indexes
	mapping(uint256 => uint256) private itemIndex;
	
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
    
     struct Token {
        uint256 id;
        uint256 salePrice;
        bool active;
        
    }
    
    /**
    * HRC721 - Harmony contract to create NFTs
    * currentPrice - Initial Sale price set by the contract owner
    * charityAddress - Org address chosen by the NFT creator
    */
    HRC721 public nftAddress;
    uint256 public currentPrice;
    address payable public charityAddress;
    mapping(uint256 => uint256) private salePrice;
    mapping(uint256 => Token) public tokens;
    

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
     * @dev Sell _tokenId for price 
     */
    function setSale(uint256 _tokenId, uint256 _price) public {
		require(nftAddress.ownerOf(_tokenId) != address(0), "setSale: nonexistent token");
		Token memory token;
		token.id = _tokenId;
		token.active = true;
		token.salePrice = _price;
		tokens[_tokenId] = token;
		
	} 
	
    /**
    * @dev Purchase _tokenId
    * @param _tokenId uint256 token ID representing an Object
    * Sends the extra bid amount to the charity address.
    */
    function purchaseToken(uint256 _tokenId) public payable whenNotPaused {
        require(msg.sender != address(0) && msg.sender != address(this));
        require(msg.value >= currentPrice, "Need to bid equal or higher than the reserve price");
        require(nftAddress.ownerOf(_tokenId) != address(0));
        require(tokens[_tokenId].active == true, "Token is not registered for sale!");
        
        /*
        De-registering the token once it's purchased.
        */
        Token memory sellingToken = tokens[_tokenId];
        sellingToken.active = false;
        tokens[_tokenId] = sellingToken;
        
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

/* 
* This is the bidding contract 
*/

contract Bidding {
    // Parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.
    address public beneficiary;
    uint public auctionEnd;

    // Current state of the auction.
    address public highestBidder;
    uint public reservePrice;
    uint public highestBid;
    
    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    // Set to true at the end, disallows any change
    bool ended;

    // Events that will be fired on changes.
    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    // The following is a so-called natspec comment,
    // recognizable by the three slashes.
    // It will be shown when the user is asked to
    // confirm a transaction.

    /// Create a simple auction with `_biddingTime`
    /// seconds bidding time on behalf of the
    /// beneficiary address `_beneficiary`.
    constructor(
        uint _biddingTime,
        address _beneficiary
    ) public {
        highestBid = reservePrice;
        beneficiary = _beneficiary;
        auctionEnd = now + _biddingTime;
    }

    /// Bid on the auction with the value sent
    /// together with this transaction.
    /// The value will only be refunded if the
    /// auction is not won.
    function bid() public payable {
        // No arguments are necessary, all
        // information is already part of
        // the transaction. The keyword payable
        // is required for the function to
        // be able to receive Ether.

        // Revert the call if the bidding
        // period is over.
        require(
            now <= auctionEnd,
            "Auction already ended."
        );

        // If the bid is not higher, send the
        // money back.
        require(
            msg.value > highestBid,
            "The bid value is less than the highest Bid."
        );

        if (highestBid != 0) {
            // Sending back the money by simply using
            // highestBidder.send(highestBid) is a security risk
            // because it could execute an untrusted contract.
            // It is always safer to let the recipients
            // withdraw their money themselves.
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    /// Withdraw a bid that was overbid.
    function withdraw() public returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `send` returns.
            pendingReturns[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                // No need to call throw here, just reset the amount owing
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function auctionEnd() public {
        // It is a good guideline to structure functions that interact
        // with other contracts (i.e. they call functions or send Ether)
        // into three phases:
        // 1. checking conditions
        // 2. performing actions (potentially changing conditions)
        // 3. interacting with other contracts
        // If these phases are mixed up, the other contract could call
        // back into the current contract and modify the state or cause
        // effects (ether payout) to be performed multiple times.
        // If functions called internally include interaction with external
        // contracts, they also have to be considered interaction with
        // external contracts.

        // 1. Conditions
        require(now >= auctionEnd, "Auction not yet ended.");
        require(!ended, "auctionEnd has already been called.");

        // 2. Effects
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        // 3. Interaction
        beneficiary.transfer(highestBid);
    }
}
