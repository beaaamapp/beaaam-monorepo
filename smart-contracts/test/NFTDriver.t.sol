// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {Caller} from "src/Caller.sol";
import {NFTDriver} from "src/NFTDriver.sol";
import {BeamsConfigImpl, BeamsHub, BeamsHistory, BeamsReceiver, SplitsReceiver, UserMetadata} from "src/BeamsHub.sol";
import {ManagedProxy} from "src/Managed.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20, ERC20PresetFixedSupply} from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract NFTDriverTest is Test {
    BeamsHub internal beamsHub;
    Caller internal caller;
    NFTDriver internal driver;
    IERC20 internal erc20;

    address internal admin = address(1);
    address internal user = address(2);
    uint256 internal tokenId;
    uint256 internal tokenId1;
    uint256 internal tokenId2;
    uint256 internal tokenIdUser;

    bytes internal constant ERROR_NOT_OWNER =
        "ERC721: caller is not token owner or approved";
    bytes internal constant ERROR_ALREADY_MINTED =
        "ERC721: token already minted";

    function setUp() public {
        BeamsHub hubLogic = new BeamsHub(10);
        beamsHub = BeamsHub(address(new ManagedProxy(hubLogic, address(this))));

        caller = new Caller();

        // Make NFTDriver's driver ID non-0 to test if it's respected by NFTDriver
        beamsHub.registerDriver(address(1));
        beamsHub.registerDriver(address(1));
        uint32 driverId = beamsHub.registerDriver(address(this));
        NFTDriver driverLogic = new NFTDriver(
            beamsHub,
            address(caller),
            driverId
        );
        driver = NFTDriver(address(new ManagedProxy(driverLogic, admin)));
        beamsHub.updateDriverAddress(driverId, address(driver));

        tokenId = driver.mint(address(this), noMetadata());
        tokenId1 = driver.mint(address(this), noMetadata());
        tokenId2 = driver.mint(address(this), noMetadata());
        tokenIdUser = driver.mint(user, noMetadata());

        erc20 = new ERC20PresetFixedSupply(
            "test",
            "test",
            type(uint136).max,
            address(this)
        );
        erc20.approve(address(driver), type(uint256).max);
        erc20.transfer(user, erc20.totalSupply() / 100);
        vm.prank(user);
        erc20.approve(address(driver), type(uint256).max);
    }

    function noMetadata()
        internal
        pure
        returns (UserMetadata[] memory userMetadata)
    {
        userMetadata = new UserMetadata[](0);
    }

    function someMetadata()
        internal
        pure
        returns (UserMetadata[] memory userMetadata)
    {
        userMetadata = new UserMetadata[](1);
        userMetadata[0] = UserMetadata("key", "value");
    }

    function assertTokenDoesNotExist(uint256 nonExistentTokenId) internal {
        vm.expectRevert("ERC721: invalid token ID");
        driver.ownerOf(nonExistentTokenId);
    }

    function testName() public {
        assertEq(driver.name(), "BeamsHub identity", "Invalid token name");
    }

    function testSymbol() public {
        assertEq(driver.symbol(), "DHI", "Invalid token symbol");
    }

    function testApproveLetsUseIdentity() public {
        vm.prank(user);
        driver.approve(address(this), tokenIdUser);
        driver.collect(tokenIdUser, erc20, address(user));
    }

    function testApproveAllLetsUseIdentity() public {
        vm.prank(user);
        driver.setApprovalForAll(address(this), true);
        driver.collect(tokenIdUser, erc20, address(user));
    }

    function testMintIncreasesTokenId() public {
        uint256 nextTokenId = driver.nextTokenId();
        assertTokenDoesNotExist(nextTokenId);

        uint256 newTokenId = driver.mint(user, someMetadata());

        assertEq(newTokenId, nextTokenId, "Invalid new tokenId");
        assertEq(driver.nextTokenId(), newTokenId + 1, "Invalid next tokenId");
        assertEq(driver.ownerOf(newTokenId), user, "Invalid token owner");
    }

    function testSafeMintIncreasesTokenId() public {
        uint256 nextTokenId = driver.nextTokenId();
        assertTokenDoesNotExist(nextTokenId);

        uint256 newTokenId = driver.safeMint(user, someMetadata());

        assertEq(newTokenId, nextTokenId, "Invalid new tokenId");
        assertEq(driver.nextTokenId(), newTokenId + 1, "Invalid next tokenId");
        assertEq(driver.ownerOf(newTokenId), user, "Invalid token owner");
    }

    function testMintWithSaltUsesUpSalt() public {
        uint64 salt = 123;
        uint256 newTokenId = driver.calcTokenIdWithSalt(address(this), salt);
        assertFalse(
            driver.isSaltUsed(address(this), salt),
            "Salt already used"
        );
        assertTokenDoesNotExist(newTokenId);

        uint256 mintedTokenId = driver.mintWithSalt(salt, user, someMetadata());

        assertEq(mintedTokenId, newTokenId, "Invalid new tokenId");
        assertTrue(driver.isSaltUsed(address(this), salt), "Salt not used");
        assertEq(driver.ownerOf(newTokenId), user, "Invalid token owner");
    }

    function testSafeMintWithSaltUsesUpSalt() public {
        uint64 salt = 123;
        uint256 newTokenId = driver.calcTokenIdWithSalt(address(this), salt);
        assertFalse(
            driver.isSaltUsed(address(this), salt),
            "Salt already used"
        );
        assertTokenDoesNotExist(newTokenId);

        uint256 mintedTokenId = driver.safeMintWithSalt(
            salt,
            user,
            someMetadata()
        );

        assertEq(mintedTokenId, newTokenId, "Invalid new tokenId");
        assertTrue(driver.isSaltUsed(address(this), salt), "Salt not used");
        assertEq(driver.ownerOf(newTokenId), user, "Invalid token owner");
    }

    function testUsedSaltCanNotBeUsedToMint() public {
        uint64 salt = 123;
        uint256 newTokenId = driver.mintWithSalt(salt, user, noMetadata());

        vm.expectRevert(ERROR_ALREADY_MINTED);
        driver.mintWithSalt(salt, user, noMetadata());

        vm.prank(user);
        driver.burn(newTokenId);
        vm.expectRevert(ERROR_ALREADY_MINTED);
        driver.mintWithSalt(salt, user, noMetadata());
    }

    function testUsedSaltCanNotBeUsedToSafeMint() public {
        uint64 salt = 123;
        uint256 newTokenId = driver.safeMintWithSalt(salt, user, noMetadata());

        vm.expectRevert(ERROR_ALREADY_MINTED);
        driver.safeMintWithSalt(salt, user, noMetadata());

        vm.prank(user);
        driver.burn(newTokenId);
        vm.expectRevert(ERROR_ALREADY_MINTED);
        driver.safeMintWithSalt(salt, user, noMetadata());
    }

    function testCollect() public {
        uint128 amt = 5;
        driver.give(tokenId1, tokenId2, erc20, amt);
        beamsHub.split(tokenId2, erc20, new SplitsReceiver[](0));
        uint256 balance = erc20.balanceOf(address(this));

        uint128 collected = driver.collect(tokenId2, erc20, address(this));

        assertEq(collected, amt, "Invalid collected");
        assertEq(
            erc20.balanceOf(address(this)),
            balance + amt,
            "Invalid balance"
        );
        assertEq(
            erc20.balanceOf(address(beamsHub)),
            0,
            "Invalid BeamsHub balance"
        );
    }

    function testCollectTransfersFundsToTheProvidedAddress() public {
        uint128 amt = 5;
        driver.give(tokenId1, tokenId2, erc20, amt);
        beamsHub.split(tokenId2, erc20, new SplitsReceiver[](0));
        address transferTo = address(1234);

        uint128 collected = driver.collect(tokenId2, erc20, transferTo);

        assertEq(collected, amt, "Invalid collected");
        assertEq(erc20.balanceOf(transferTo), amt, "Invalid balance");
        assertEq(
            erc20.balanceOf(address(beamsHub)),
            0,
            "Invalid BeamsHub balance"
        );
    }

    function testCollectRevertsWhenNotTokenHolder() public {
        vm.expectRevert(ERROR_NOT_OWNER);
        driver.collect(tokenIdUser, erc20, address(this));
    }

    function testGive() public {
        uint128 amt = 5;
        uint256 balance = erc20.balanceOf(address(this));

        driver.give(tokenId1, tokenId2, erc20, amt);

        assertEq(
            erc20.balanceOf(address(this)),
            balance - amt,
            "Invalid balance"
        );
        assertEq(
            erc20.balanceOf(address(beamsHub)),
            amt,
            "Invalid BeamsHub balance"
        );
        assertEq(
            beamsHub.splittable(tokenId2, erc20),
            amt,
            "Invalid received amount"
        );
    }

    function testGiveRevertsWhenNotTokenHolder() public {
        vm.expectRevert(ERROR_NOT_OWNER);
        driver.give(tokenIdUser, tokenId, erc20, 5);
    }

    function testSetBeams() public {
        uint128 amt = 5;

        // Top-up

        BeamsReceiver[] memory receivers = new BeamsReceiver[](1);
        receivers[0] = BeamsReceiver(
            tokenId2,
            BeamsConfigImpl.create(0, beamsHub.minAmtPerSec(), 0, 0)
        );
        uint256 balance = erc20.balanceOf(address(this));

        int128 realBalanceDelta = driver.setBeams(
            tokenId1,
            erc20,
            new BeamsReceiver[](0),
            int128(amt),
            receivers,
            0,
            0,
            address(this)
        );

        assertEq(
            erc20.balanceOf(address(this)),
            balance - amt,
            "Invalid balance after top-up"
        );
        assertEq(
            erc20.balanceOf(address(beamsHub)),
            amt,
            "Invalid BeamsHub balance after top-up"
        );
        (, , , uint128 beamsBalance, ) = beamsHub.beamsState(tokenId1, erc20);
        assertEq(beamsBalance, amt, "Invalid beams balance after top-up");

        assertEq(
            realBalanceDelta,
            int128(amt),
            "Invalid beams balance delta after top-up"
        );
        (bytes32 beamsHash, , , , ) = beamsHub.beamsState(tokenId1, erc20);
        assertEq(
            beamsHash,
            beamsHub.hashBeams(receivers),
            "Invalid beams hash after top-up"
        );

        // Withdraw
        balance = erc20.balanceOf(address(user));

        realBalanceDelta = driver.setBeams(
            tokenId1,
            erc20,
            receivers,
            -int128(amt),
            receivers,
            0,
            0,
            address(user)
        );

        assertEq(
            erc20.balanceOf(address(user)),
            balance + amt,
            "Invalid balance after withdrawal"
        );
        assertEq(
            erc20.balanceOf(address(beamsHub)),
            0,
            "Invalid BeamsHub balance after withdrawal"
        );
        (, , , beamsBalance, ) = beamsHub.beamsState(tokenId1, erc20);
        assertEq(beamsBalance, 0, "Invalid beams balance after withdrawal");
        assertEq(
            realBalanceDelta,
            -int128(amt),
            "Invalid beams balance delta after withdrawal"
        );
    }

    function testSetBeamsDecreasingBalanceTransfersFundsToTheProvidedAddress()
        public
    {
        uint128 amt = 5;
        BeamsReceiver[] memory receivers = new BeamsReceiver[](0);
        driver.setBeams(
            tokenId,
            erc20,
            receivers,
            int128(amt),
            receivers,
            0,
            0,
            address(this)
        );
        address transferTo = address(1234);

        int128 realBalanceDelta = driver.setBeams(
            tokenId,
            erc20,
            receivers,
            -int128(amt),
            receivers,
            0,
            0,
            transferTo
        );

        assertEq(erc20.balanceOf(transferTo), amt, "Invalid balance");
        assertEq(
            erc20.balanceOf(address(beamsHub)),
            0,
            "Invalid BeamsHub balance"
        );
        (, , , uint128 beamsBalance, ) = beamsHub.beamsState(tokenId1, erc20);
        assertEq(beamsBalance, 0, "Invalid beams balance");
        assertEq(realBalanceDelta, -int128(amt), "Invalid beams balance delta");
    }

    function testSetBeamsRevertsWhenNotTokenHolder() public {
        BeamsReceiver[] memory noReceivers = new BeamsReceiver[](0);
        vm.expectRevert(ERROR_NOT_OWNER);
        driver.setBeams(
            tokenIdUser,
            erc20,
            noReceivers,
            0,
            noReceivers,
            0,
            0,
            address(this)
        );
    }

    function testSetSplits() public {
        SplitsReceiver[] memory receivers = new SplitsReceiver[](1);
        receivers[0] = SplitsReceiver(tokenId2, 1);

        driver.setSplits(tokenId, receivers);

        bytes32 actual = beamsHub.splitsHash(tokenId);
        bytes32 expected = beamsHub.hashSplits(receivers);
        assertEq(actual, expected, "Invalid splits hash");
    }

    function testSetSplitsRevertsWhenNotTokenHolder() public {
        vm.expectRevert(ERROR_NOT_OWNER);
        driver.setSplits(tokenIdUser, new SplitsReceiver[](0));
    }

    function testEmitUserMetadata() public {
        UserMetadata[] memory userMetadata = new UserMetadata[](1);
        userMetadata[0] = UserMetadata("key", "value");
        driver.emitUserMetadata(tokenId, userMetadata);
    }

    function testEmitUserMetadataRevertsWhenNotTokenHolder() public {
        UserMetadata[] memory userMetadata = new UserMetadata[](1);
        userMetadata[0] = UserMetadata("key", "value");
        vm.expectRevert(ERROR_NOT_OWNER);
        driver.emitUserMetadata(tokenIdUser, userMetadata);
    }

    function testForwarderIsTrustedInErc721Calls() public {
        vm.prank(user);
        caller.authorize(address(this));
        assertEq(
            driver.ownerOf(tokenIdUser),
            user,
            "Invalid token owner before transfer"
        );

        bytes memory transferFromData = abi.encodeWithSelector(
            driver.transferFrom.selector,
            user,
            address(this),
            tokenIdUser
        );
        caller.callAs(user, address(driver), transferFromData);

        assertEq(
            driver.ownerOf(tokenIdUser),
            address(this),
            "Invalid token owner after transfer"
        );
    }

    function testForwarderIsTrustedInDriverCalls() public {
        vm.prank(user);
        caller.authorize(address(this));
        assertEq(
            beamsHub.splittable(tokenId, erc20),
            0,
            "Invalid splittable before give"
        );
        uint128 amt = 10;

        bytes memory giveData = abi.encodeWithSelector(
            driver.give.selector,
            tokenIdUser,
            tokenId,
            erc20,
            amt
        );
        caller.callAs(user, address(driver), giveData);

        assertEq(
            beamsHub.splittable(tokenId, erc20),
            amt,
            "Invalid splittable after give"
        );
    }

    modifier canBePausedTest() {
        vm.prank(admin);
        driver.pause();
        vm.expectRevert("Contract paused");
        _;
    }

    function testMintCanBePaused() public canBePausedTest {
        driver.mint(user, noMetadata());
    }

    function testSafeMintCanBePaused() public canBePausedTest {
        driver.safeMint(user, noMetadata());
    }

    function testCollectCanBePaused() public canBePausedTest {
        driver.collect(0, erc20, user);
    }

    function testGiveCanBePaused() public canBePausedTest {
        driver.give(0, 0, erc20, 0);
    }

    function testSetBeamsCanBePaused() public canBePausedTest {
        driver.setBeams(
            0,
            erc20,
            new BeamsReceiver[](0),
            0,
            new BeamsReceiver[](0),
            0,
            0,
            user
        );
    }

    function testSetSplitsCanBePaused() public canBePausedTest {
        driver.setSplits(0, new SplitsReceiver[](0));
    }

    function testEmitUserMetadataCanBePaused() public canBePausedTest {
        driver.emitUserMetadata(0, noMetadata());
    }

    function testBurnCanBePaused() public canBePausedTest {
        driver.burn(0);
    }

    function testApproveCanBePaused() public canBePausedTest {
        driver.approve(user, 0);
    }

    function testSafeTransferFromCanBePaused() public canBePausedTest {
        driver.safeTransferFrom(user, user, 0);
    }

    function testSafeTransferFromWithDataCanBePaused() public canBePausedTest {
        driver.safeTransferFrom(user, user, 0, new bytes(0));
    }

    function testSetApprovalForAllCanBePaused() public canBePausedTest {
        driver.setApprovalForAll(user, false);
    }

    function testTransferFromCanBePaused() public canBePausedTest {
        driver.transferFrom(user, user, 0);
    }
}
