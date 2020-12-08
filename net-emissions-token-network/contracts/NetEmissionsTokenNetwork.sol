pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract NetEmissionsTokenNetwork is ERC1155, AccessControl {
    
    bytes32 public constant REGISTERED_DEALER = keccak256("REGISTERED_DEALER");
    bytes32 public constant REGISTERED_CONSUMER = keccak256("REGISTERED_CONSUMER");
    
    struct CarbonTokenDetails {
        uint256 tokenId;   // token Id   (must be unique)
        string tokenTypeId;
        string issuerId;
        string recipientId;
        string uom;
        string fromDate;
        string thruDate;
        uint256 dateCreated;
        string metadata;
        string manifest;
        string description;
        bool retired;
        string automaticRetireDate;
    }

    mapping (uint256 => CarbonTokenDetails) private _tokenDetails;    // tokenId to tokenDefinition
    uint256[] private _tokenIds;    // array of tokens
    string[] _validTokenTypeIds = ["Renewable Energy Certificate", "Carbon Emissions Offset", "Audited Emissions"];
    
    event CarbonTokenDefined(uint256 tokenId);
    event RegisteredDealer(address indexed account );
    event UnregisteredDealer(address indexed account );

    constructor(address minter) ERC1155("localhost") public {
        _setupRole(DEFAULT_ADMIN_ROLE, minter);
        _setupRole(REGISTERED_DEALER, minter);

    }
    
    modifier consumerOrDealer () {
        bool isConsumer = hasRole(REGISTERED_CONSUMER, msg.sender);
        bool isDealer = hasRole(REGISTERED_DEALER, msg.sender);
        require(isConsumer || isDealer, "You must be either a consumer or a dealer.");

        _;
    }
    
    modifier onlyDealer() {
        require(hasRole(REGISTERED_DEALER, msg.sender), "You are not a dealer");
        _;
    }

    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "You are not the owner.");
        _;
    }


    /**
     * @dev returns true if the tokenId already exists (already defined by contract owner)
     */
    function tokenExists( uint256 tokenId ) private view returns( bool ) {
        uint256 idx;
        for( idx = 0; idx < _tokenIds.length; idx++ ) {
            if( _tokenIds[idx] == tokenId )
                return true;
        }
        return false; // no matching tokenId
    }
    
    function tokenTypeIdIsValid( string memory tokenTypeId ) private view returns( bool ) {
        uint256 idx;
        for( idx = 0; idx < _validTokenTypeIds.length; idx++ ) {
            if( keccak256(bytes(_validTokenTypeIds[idx])) == keccak256(bytes(tokenTypeId)) )
                return true;
        }
        return false; // no matching tokenId
    }

    /**
    * @dev returns ids of all tokens
    */
    function getAllTokenIds( ) public view returns ( uint256[] memory ) {
        return _tokenIds;
    }

    /**
     * @dev External function to mint an amount of a token for the given tokenId
     * Only contract owner can call this function
     * This function can be called any number of times to add to the current total for a given tokenId
     * @param tokenId of the token to mint
     * @param quantity of the token to mint For ex: if one needs 100 full tokens, the caller 
     * should set the amount as (100 * 10^4) = 1,000,000 (assuming the token's decimals is set to 4)
     */
     
    function issue( address account, uint256 tokenId, uint256 quantity, string memory issuerId, string memory recipientId, string memory uom, string memory fromDate, string memory thruDate, string memory metadata, string memory manifest, string memory automaticRetireDate ) public onlyDealer {
        require(hasRole(REGISTERED_CONSUMER, account), "The token address supplied must be a registered consumer.");
        require( tokenExists( tokenId ), "tokenId does not exist");
        require( tokenTypeIdIsValid ( _tokenDetails[tokenId].tokenTypeId ), "Failed to mint: tokenTypeId is invalid.");
        bytes memory callData;
        
        
        CarbonTokenDetails storage tokenInfo = _tokenDetails[ tokenId ];
        tokenInfo.issuerId = issuerId;
        tokenInfo.recipientId = recipientId;
        tokenInfo.uom = uom;
        tokenInfo.fromDate = fromDate;
        tokenInfo.thruDate = thruDate;
        tokenInfo.metadata = metadata;
        tokenInfo.manifest = manifest;
        tokenInfo.dateCreated = now;
        tokenInfo.automaticRetireDate = automaticRetireDate;
        
        
        super._mint( account, tokenId, quantity, callData);
        // minter = address( msg.sender );    or minter = msg.sender;
    }

   /** 
    * @dev returns if the caller is the owner
    */
    function isOwner( ) external view returns( bool ) {
        return(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
    }

   /** 
    * @dev returns the token decimals for the given token
    * @param tokenId token to check 
    */
//  function getDecimals( uint256 tokenId ) external view returns( uint8 ) {
//         require( tokenExists( tokenId ), "tokenId does not exist");
//      return( _tokenDetails[tokenId].decimals );
//  }

   /** 
    * @dev returns the token name for the given token
    * @param tokenId token to check 
    */
    function getTokenName( uint256 tokenId ) external view returns( string memory ) {
        require( tokenExists( tokenId ), "tokenId does not exist");
        string memory tokenName = _tokenDetails[tokenId].tokenTypeId;
        return tokenName;
    }

       /** 
    * @dev returns the token name for the given token
    * @param tokenId token to check 
    */
    function getTokenType( uint256 tokenId ) external view returns( string memory ) {
        require( tokenExists( tokenId ), "tokenId does not exist");
        string memory tokenType = _tokenDetails[tokenId].tokenTypeId;
        return tokenType;
    }

   /** 
    * @dev returns the TTF (Token Taxonomy Framework) token specs URL for the given token
    * @param tokenId token to check 
    */
//  function getTTF_URL( uint256 tokenId ) external view returns( string memory ) {
//         require( tokenExists( tokenId ), "tokenId does not exist");
//      string memory ttfUrl = _tokenDetails[tokenId].TTF_url;
//      return( ttfUrl );
//  }

   /** 
    * @dev checks if the token is in retired state 
    * @param tokenId token to check 
    */
    function isRetired( uint256 tokenId ) public view returns( bool ) {
        require( tokenExists( tokenId ), "tokenId does not exist");
        return( _tokenDetails[tokenId].retired );
    }

   /** 
    * @dev sets the token to the retire state to disable transfers, mints and burns
    * @param tokenId token to set in pause state
    *   Only contract owner can pause or resume tokens
    */
    function retire( address account, uint256 tokenId, uint256 amount) external onlyDealer {
        require( tokenExists( tokenId ), "tokenId does not exist");
        require( (_tokenDetails[tokenId].retired == false), "token is already retired");
        _tokenDetails[tokenId].retired = true;
        super._burn( account, tokenId, amount );
    }

   /** 
    * @dev returns true if Dealer's account is registered for the given token
    * @param account address of the dealer 
    *   Only contract owner can check for dealer registration
    */
    function isDealerRegistered( address account ) external onlyOwner view returns( bool ) {
        return hasRole(REGISTERED_DEALER, account);
    }

   /** 
    * @dev Only CB (Owner or address(0)) can register Dealers
    * @param account address of the dealer to register
    * Only registered Dealers can transfer tokens 
    */
   function registerDealer( address account ) external onlyOwner {
        grantRole(REGISTERED_DEALER, account);
        emit RegisteredDealer( account );
    }
    
   /** 
    * @dev returns true if Consumer's account is registered for the given token
    * @param account address of the consumer 
    *   Only contract owner can check for consumer registration
    */
     function registerConsumer( address account ) external onlyDealer {
        grantRole(REGISTERED_CONSUMER, account);
        emit RegisteredDealer( account );
    }
    
    function isConsumerRegistered( address account ) external onlyDealer view returns( bool ) {
        // require(hasRole(REGISTERED_CONSUMER, account), "Consumer is not registed");
        return hasRole(REGISTERED_CONSUMER, account);
    }

    /** 
     * @dev returns true if all the token balances for the account are 0
     * @param account address of the account to which all token balances to be checked
     */
    function checkAllBalancesAreZero( address account ) private view returns( bool ) {
        uint256 idx;
        for( idx = 0; idx < _tokenIds.length; idx++ ) {
            if( super.balanceOf( account, _tokenIds[idx] ) != 0 )
                return false;
        }
        return true; // all token balances are 0 
    }

    /** 
     * @dev returns true if the token balance for the account & tolem is 0
     * @param account address of the account for which token balance to be checked
     * @param tokenId tokenId for which balance to be checked
     */
    function checkBalance( address account, uint256 tokenId ) private view returns( bool ) {
        uint256 idx;
        for( idx = 0; idx < _tokenIds.length; idx++ ) {
            if( _tokenIds[idx] == tokenId ) {
                return ( super.balanceOf( account, _tokenIds[idx] ) == 0 );
            }
        }
        return true; // no matching token: token balance is 0 by defailt
    }

    /** 
     * @dev Only CB (Owner or address(0)) can unregister Dealers
     * @param account address to be unregistered
     *  Only accounts with 0 balance can be unregistered 
     */
    function unregisterDealer( address account ) external onlyOwner {
        this.setApprovalForAll( account, false );  // enable this contract as approved in ERC1155 contract for xacting with the owner address 
        super.revokeRole("REGISTERED_DEALER", account);
        emit UnregisteredDealer( account );
    }

    /** 
     * @dev Only CB (Owner or address(0)) can unregister Consumers
     * @param account address to be unregistered
     *  Only accounts with 0 balance can be unregistered 
     */
    function unregisterConsumer( address account ) external onlyDealer {
        this.setApprovalForAll( account, false );  // enable this contract as approved in ERC1155 contract for xacting with the owner address 
        super.revokeRole("REGISTERED_CONSUMER", account);
        emit UnregisteredDealer( account );
    }

    /** 
     * @dev transfers the value to the 'to' account for tokenId
     * @param to recipient address 
     * @param tokenId tokenId for the transfer
     * @param value amount of transfer
     *  Transfer can start only when both parties are registered and the token is not paused
     */
    function transfer(
        address to,
        uint256 tokenId,
        uint256 value
    ) external {
        require( tokenExists( tokenId ), "tokenId does not exist");
        require( ( isRetired( tokenId ) == false ), "Token is retired. Transfer is not permitted" );
        require(hasRole(REGISTERED_DEALER, msg.sender), "Caller is not a minter");
        require(hasRole(REGISTERED_DEALER,to), "Caller is not a minter");
        require( ( msg.sender != to), "sender and receiver cannot be the same" );
        this.safeTransferFrom( msg.sender, to, tokenId, value, '0x00' );
    }

    // /** 
    //  * @dev returns the balance of the account for the given token
    //  * @param account address for which balance to be checked
    //  * @param tokenId tokenId for the balance query
    //  * Balance will be provided only for registered account
    //  */
    // function balanceOf( address account, uint256 tokenId ) public view override onlyOwner returns (uint256) {
    // //   require( _tokenDetails[tokenId].registeredDealers.has( account ), 
    // //       "dealer account must be registered first" );
    //  return super.balanceOf( account, tokenId );
    // }

    // function balanceOf( uint256 tokenId ) external view returns (uint256) {
    //  require( _tokenDetails[tokenId].registeredDealers.has( msg.sender ), 
    //      "dealer account must be registered first" );
    //  return super.balanceOf( msg.sender, tokenId );
    // }

   /**
    struct TokenBalance {
        uint256 tokenId;
        uint256 balance;
        string name; 
    }
    **/

/**
  * to enable the following function, we have to enable the pragma:
  * new experimental ABI encoder. Use "pragma experimental ABIEncoderV2;" 
  * 
  * memory is expensive in terms of gas. However in private network gas cost is assumed 0. 
    function getTokenBalances( ) public view returns ( TokenBalance[] memory ) {
        uint256 numTokens = _tokenIds.length;
        TokenBalance[] memory tokBalA = new TokenBalance[]( numTokens );
        for( uint i= 0; i < numTokens; i++ ) {
            uint256 tokenId = _tokenIds[i];
            TokenBalance memory tokBal; // = new TokenBalance;
            tokBal.tokenId = tokenId;
            tokBal.balance = super.balanceOf( msg.sender, tokenId );
            tokBal.name = _tokenDetails[tokenId].name;
            tokBalA[i] = tokBal;
        }
        return tokBalA;
    }

    // deprecated: all allocations are now handled via transfer
    function allocate(
        address to,
        uint256 tokenId,
        uint256 value
    ) private onlyOwner {
        require( _tokenDetails[tokenId].registeredDealers.has( to ), "receiver must be registered first" );
        require( ( to != owner), "receiver must not be contract owner" );
        this.safeTransferFrom( msg.sender, to, tokenId, value, '0x00' );
    }

    // deprecated: all unallocations are now handled via transfer
    function unallocate (
        address from,
        uint256 tokenId,
        uint256 value
    ) private onlyOwner {
        require( _tokenDetails[tokenId].registeredDealers.has( from ), "from dealer account must be registered first" );
        require( ( from != owner), "sender must not be contract owner" );
        this.safeTransferFrom( from, msg.sender, tokenId, value, '0x00' );
    }

 ******/


}