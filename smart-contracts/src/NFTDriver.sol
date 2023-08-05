// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;
import {BeamsHub, BeamsReceiver, IERC20, SafeERC20, SplitsReceiver, UserMetadata} from "./BeamsHub.sol";
import {Managed} from "./Managed.sol";
import {Context, ERC2771Context} from "openzeppelin-contracts/metatx/ERC2771Context.sol";
import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";
import {ERC721, ERC721Burnable, IERC721, IERC721Metadata} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract NFTDriver is ERC721Burnable, ERC2771Context, Managed {
    using SafeERC20 for IERC20;
    BeamsHub public immutable beamsHub;
    uint32 public immutable driverId;
    bytes32 private immutable _nftDriverStorageSlot =
        _erc1967Slot("eip1967.nftDriver.storage");
    struct NFTDriverStorage {
        uint64 mintedTokens;
        mapping(address minter => mapping(uint64 salt => bool)) isSaltUsed;
    }

    constructor(
        BeamsHub _beamsHub,
        address forwarder,
        uint32 _driverId
    ) ERC2771Context(forwarder) ERC721("", "") {
        beamsHub = _beamsHub;
        driverId = _driverId;
    }

    modifier onlyHolder(uint256 tokenId) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    function nextTokenId() public view returns (uint256 tokenId) {
        return
            calcTokenIdWithSalt(address(0), _nftDriverStorage().mintedTokens);
    }

    function calcTokenIdWithSalt(
        address minter,
        uint64 salt
    ) public view returns (uint256 tokenId) {
        tokenId = driverId;
        tokenId = (tokenId << 160) | uint160(minter);
        tokenId = (tokenId << 64) | salt;
    }

    function isSaltUsed(
        address minter,
        uint64 salt
    ) public view returns (bool isUsed) {
        return _nftDriverStorage().isSaltUsed[minter][salt];
    }

    function mint(
        address to,
        UserMetadata[] calldata userMetadata
    ) public whenNotPaused returns (uint256 tokenId) {
        tokenId = _registerTokenId();
        _mint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    function safeMint(
        address to,
        UserMetadata[] calldata userMetadata
    ) public whenNotPaused returns (uint256 tokenId) {
        tokenId = _registerTokenId();
        _safeMint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    function _registerTokenId() internal returns (uint256 tokenId) {
        tokenId = nextTokenId();
        _nftDriverStorage().mintedTokens++;
    }

    function mintWithSalt(
        uint64 salt,
        address to,
        UserMetadata[] calldata userMetadata
    ) public whenNotPaused returns (uint256 tokenId) {
        tokenId = _registerTokenIdWithSalt(salt);
        _mint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    function safeMintWithSalt(
        uint64 salt,
        address to,
        UserMetadata[] calldata userMetadata
    ) public whenNotPaused returns (uint256 tokenId) {
        tokenId = _registerTokenIdWithSalt(salt);
        _safeMint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    function _registerTokenIdWithSalt(
        uint64 salt
    ) internal returns (uint256 tokenId) {
        address minter = _msgSender();
        require(!isSaltUsed(minter, salt), "ERC721: token already minted");
        _nftDriverStorage().isSaltUsed[minter][salt] = true;
        return calcTokenIdWithSalt(minter, salt);
    }

    function collect(
        uint256 tokenId,
        IERC20 erc20,
        address transferTo
    ) public whenNotPaused onlyHolder(tokenId) returns (uint128 amt) {
        amt = beamsHub.collect(tokenId, erc20);
        if (amt > 0) beamsHub.withdraw(erc20, transferTo, amt);
    }

    function give(
        uint256 tokenId,
        uint256 receiver,
        IERC20 erc20,
        uint128 amt
    ) public whenNotPaused onlyHolder(tokenId) {
        if (amt > 0) _transferFromCaller(erc20, amt);
        beamsHub.give(tokenId, receiver, erc20, amt);
    }

    function setBeams(
        uint256 tokenId,
        IERC20 erc20,
        BeamsReceiver[] calldata currReceivers,
        int128 balanceDelta,
        BeamsReceiver[] calldata newReceivers,
        uint32 maxEndHint1,
        uint32 maxEndHint2,
        address transferTo
    )
        public
        whenNotPaused
        onlyHolder(tokenId)
        returns (int128 realBalanceDelta)
    {
        if (balanceDelta > 0) _transferFromCaller(erc20, uint128(balanceDelta));
        realBalanceDelta = beamsHub.setBeams(
            tokenId,
            erc20,
            currReceivers,
            balanceDelta,
            newReceivers,
            maxEndHint1,
            maxEndHint2
        );
        if (realBalanceDelta < 0)
            beamsHub.withdraw(erc20, transferTo, uint128(-realBalanceDelta));
    }

    function setSplits(
        uint256 tokenId,
        SplitsReceiver[] calldata receivers
    ) public whenNotPaused onlyHolder(tokenId) {
        beamsHub.setSplits(tokenId, receivers);
    }

    function emitUserMetadata(
        uint256 tokenId,
        UserMetadata[] calldata userMetadata
    ) public whenNotPaused onlyHolder(tokenId) {
        _emitUserMetadata(tokenId, userMetadata);
    }

    function _emitUserMetadata(
        uint256 tokenId,
        UserMetadata[] calldata userMetadata
    ) internal {
        if (userMetadata.length == 0) return;
        beamsHub.emitUserMetadata(tokenId, userMetadata);
    }

    function name() public pure override returns (string memory) {
        return "BeamsHub identity";
    }

    function symbol() public pure override returns (string memory) {
        return "DHI";
    }

    function burn(uint256 tokenId) public override whenNotPaused {
        super.burn(tokenId);
    }

    function approve(
        address to,
        uint256 tokenId
    ) public override whenNotPaused {
        super.approve(to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override whenNotPaused {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public override whenNotPaused {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused {
        super.transferFrom(from, to, tokenId);
    }

    function _transferFromCaller(IERC20 erc20, uint128 amt) internal {
        erc20.safeTransferFrom(_msgSender(), address(beamsHub), amt);
    }

    function _msgSender()
        internal
        view
        override(Context, ERC2771Context)
        returns (address)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function _nftDriverStorage()
        internal
        view
        returns (NFTDriverStorage storage storageRef)
    {
        bytes32 slot = _nftDriverStorageSlot;
        assembly {
            storageRef.slot := slot
        }
    }
}
