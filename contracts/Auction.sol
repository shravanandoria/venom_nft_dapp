pragma ever-solidity >= 0.61.2;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
    
// Interfaces we needs
// This interface for transferring NFT to winner
import "@itgold/everscale-tip/contracts/TIP4_1/interfaces/ITIP4_1NFT.sol";
// This interface to accept NFT from owner
import "@itgold/everscale-tip/contracts/TIP4_1/interfaces/INftTransfer.sol";
// This interface for implementing tip-3 tokens receiving callback
import "tip3/contracts/interfaces/IAcceptTokensTransferCallback.sol";
// This interface for deploying TokenWallet
import "tip3/contracts/interfaces/ITokenRoot.sol";
// This interface to return lower bids
import "tip3/contracts/interfaces/ITokenWallet.sol";

contract Auction is INftTransfer, IAcceptTokensTransferCallback {
    
    uint256 static _nonce; // random nonce for affecting on address
    address static _owner; // owner of auction and nft

    // uint32  public _startTime; // auction start time timestmp in seconds
    // uint32  public _endTime; // auction end time timestamp in seconds

    address public _nft; // nft which will be sell
    
    uint128 public _currentBid; // state for holding current max bid
    address public _currentWinner; // current max bid owner

    address public _tokenRoot; // this token we will receive for bids
    address public _tokenWallet; // wallet for receive bids

    bool public _nftReceived; // is auction already receive nft
    bool public _closed; // action end flag

    constructor(
        address tokenRoot,
        address sendRemainingGasTo
    ) public {
        tvm.accept();
        tvm.rawReserve(0.2 ever, 0);
        
        _nftReceived = false;
        _closed = false;

        // _startTime = startTime;
        // _endTime = endTime;

        _tokenRoot = tokenRoot;
        // familiar wallet deploying mechanic
        ITokenRoot(_tokenRoot).deployWallet {
            value: 0.2 ever,
            flag: 1,
            callback: Auction.onTokenWallet
        } (
            address(this),
            0.1 ever
        );
        // memento gas management :)
        sendRemainingGasTo.transfer({ value: 0, flag: 128, bounce: false });
    }

    function onTokenWallet(address value) external {
        require (
            msg.sender.value != 0 &&
            msg.sender == _tokenRoot,
            101
        );
        tvm.rawReserve(0.2 ever, 0);
        // just store our auction's wallet address for future interaction
        _tokenWallet = value;
        _owner.transfer({ value: 0, flag: 128, bounce: false });
    }

    function onNftTransfer(
        uint256, // id,
        address oldOwner,
        address, // newOwner,
        address, // oldManager,
        address, // newManager,
        address, // collection,
        address gasReceiver,
        TvmCell // payload
    ) override external {
        tvm.rawReserve(0.2 ever, 0);
        if (oldOwner != _owner || _nftReceived) {
        // we should return an NFT, received from address, differenced from owner we sets in state
            mapping(address => ITIP4_1NFT.CallbackParams) empty;
            // just operating with interface
            ITIP4_1NFT(msg.sender).transfer{
                value: 0,
                flag: 128,
                bounce: false
            }(
                oldOwner,
                gasReceiver,
                empty
            );
        } else {
            // positive case: we got an NFT for selling!
            _nft = msg.sender;
            _nftReceived = true;
        }
    }

    function finishAuction(
        address sendRemainingGasTo
    ) public {
        // remember about gas management...and about gas constants libraries too :)
        tvm.rawReserve(0.2 ever, 0);
            // bid more than zero, so somebody has won! let's send NFT to winner
        mapping(address => ITIP4_1NFT.CallbackParams) noCallbacks;
        TvmCell empty;
        ITIP4_1NFT(_nft).transfer{
            value: 0.1 ever,
            flag: 1,
            bounce: false
        }(
            _currentWinner,
            sendRemainingGasTo,
            noCallbacks
        );
        // do not forget to send bid amount for auction owner!
        ITokenWallet(_tokenWallet).transfer{value: 0, flag: 128}(
            _currentBid,
            _owner,
            0.1 ever,
            sendRemainingGasTo,
            true,
            empty
        );
        
    }

}