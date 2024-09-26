// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ProtocolFacet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/model/Protocol.sol";


contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolFacet;


    address USDTHolders = 0xCEFc1C9af894a9dFBF763A394E6588b0b4D9a5a8;
    address DAIHolders = 0xCEFc1C9af894a9dFBF763A394E6588b0b4D9a5a8;
    address LINKHolders = 0xCEFc1C9af894a9dFBF763A394E6588b0b4D9a5a8;
    address WETHHolders = 0x0a4CAA57ac414f6B936261ff7CB1d6883bBF7264;

    address USDT_USD = 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f;
    address DIA_USD = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;
    address LINK_USD = 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61;
    address WETH_USD = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;

    address USDT_CONTRACT_ADDRESS = 0x00D1C02E008D594ebEFe3F3b7fd175850f96AEa0;
    address WETH_CONTRACT_ADDRESS = 0x7fEa3ea63433a35e8516777171D7d0e038804716;
    address DIA_CONTRACT_ADDRESS = 0x5caF98bf477CBE96d5CA56039FE7beec457bA653;
    address LINK_CONTRACT_ADDRESS = 0xb58c2e70c750CBAA1a2d487Dd0BfF26be92F5308;

    address owner = address(0xa);
    address B = address(0xb);
    address C = address(0xc);

    address[] tokens;
    address[] priceFeed;



    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();


        owner = mkaddr("owner");
        B = mkaddr("B address");
        C = mkaddr("C address");
      



        tokens.push(USDT_CONTRACT_ADDRESS);
        tokens.push(DIA_CONTRACT_ADDRESS);
        tokens.push(LINK_CONTRACT_ADDRESS);
        tokens.push(WETH_CONTRACT_ADDRESS);

        priceFeed.push(USDT_USD);
        priceFeed.push(DIA_USD);
        priceFeed.push(LINK_USD);
        priceFeed.push(WETH_USD);


        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

         cut[2] = (
            FacetCut({
                facetAddress: address(protocolFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ProtocolFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        ///@notice set protocol constructor by the diamond
        diamond.initialize(tokens, priceFeed);

        protocolFacet = ProtocolFacet(address(diamond));

        // protocolFacet.approveUserToSpendTokens(DIA_CONTRACT_ADDRESS, B, type(uint).max);

       
        switchSigner(owner);
        IERC20(USDT_CONTRACT_ADDRESS).approve(address(protocolFacet),type(uint).max);
        IERC20(DIA_CONTRACT_ADDRESS).approve(address(protocolFacet), type(uint).max);
        IERC20(WETH_CONTRACT_ADDRESS).approve(address(protocolFacet),type(uint).max);

        // switchSigner(address(protocolFacet));
        // IERC20(DIA_CONTRACT_ADDRESS).approve(B, type(uint).max);
        // IERC20(USDT_CONTRACT_ADDRESS).approve(B, type(uint).max);
        // IERC20(WETH_CONTRACT_ADDRESS).approve(B, type(uint).max);

        transferTokenToOwner();

    }

     function testDepositTCollateral() public {
        switchSigner(owner);
        protocolFacet.depositCollateral(USDT_CONTRACT_ADDRESS, 1000000);
        uint256 _amountQualaterized = protocolFacet
            .gets_addressToCollateralDeposited(owner, USDT_CONTRACT_ADDRESS);
        assertEq(_amountQualaterized, 1000000);
    }


    function testUserCanCreateTwoRequest() public {
        testDepositTCollateral();

        switchSigner(owner);

        uint128 requestAmount = 10000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days;

        protocolFacet.createLendingRequest(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );
        protocolFacet.createLendingRequest(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );

        // Verify that the request is correctly added
        
        Request[] memory requests = protocolFacet.getAllRequest();
        assertEq(requests.length, 2);
        assertEq(requests[0].amount, requestAmount);
    }


        function testExcessiveBorrowing() public {
        testDepositTCollateral();
        switchSigner(owner);

        uint128 requestAmount = 100000000000;

        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days; // 1 year later
        vm.expectRevert(
            abi.encodeWithSelector(Protocol__InsufficientCollateral.selector)
        );
        protocolFacet.createLendingRequest(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );
    }

     function testServiceRequest() public {
        // IERC20 daiContract = IERC20(WETHHolders);
        // switchSigner(WETHHolders);
        switchSigner(owner);
        IERC20(LINK_CONTRACT_ADDRESS).transfer(B, 10000);
        testDepositTCollateral();

        uint128 requestAmount = 10000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days; // 1 year later

        uint256 borrowerDAIStartBalance = IERC20(LINK_CONTRACT_ADDRESS)
            .balanceOf(owner);
        switchSigner(owner);
        protocolFacet.createLendingRequest(
            requestAmount,
            interestRate,
            returnDate,
            LINK_CONTRACT_ADDRESS
        );

        switchSigner(B);
        IERC20(LINK_CONTRACT_ADDRESS).approve(address(protocolFacet), requestAmount);
        protocolFacet.serviceRequest(1, LINK_CONTRACT_ADDRESS);
        assertEq(
            IERC20(LINK_CONTRACT_ADDRESS).balanceOf(owner),
            borrowerDAIStartBalance + requestAmount
        );
        Request memory _borrowRequest = protocolFacet.getUserRequest(
            owner,
            1
        );

        assertEq(_borrowRequest.lender, B);
        assertEq(uint8(_borrowRequest.status), uint8(1));
    }

    function testServiceRequestFailsAfterFirstService() public {
        switchSigner(owner);
        IERC20(LINK_CONTRACT_ADDRESS).transfer(B, 10000);
        testDepositTCollateral();

        uint128 requestAmount = 10000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days; // 1 year later

        protocolFacet.createLendingRequest(
            requestAmount,
            interestRate,
            returnDate,
            LINK_CONTRACT_ADDRESS
        );

        switchSigner(B);
        IERC20(LINK_CONTRACT_ADDRESS).approve(address(protocolFacet), requestAmount);
        protocolFacet.serviceRequest(1, LINK_CONTRACT_ADDRESS);

        vm.expectRevert(
            abi.encodeWithSelector(Protocol__RequestNotOpen.selector)
        );

        protocolFacet.serviceRequest(1, LINK_CONTRACT_ADDRESS);

        // NOTE to ensure it is not just the first person to service the request it fails for
        switchSigner(C);
        vm.expectRevert(
            abi.encodeWithSelector(Protocol__RequestNotOpen.selector)
        );

        protocolFacet.serviceRequest(1, LINK_CONTRACT_ADDRESS);
    }

        function testServiceRequestFailsWithoutTokenAllowance() public {
        switchSigner(owner);
        IERC20(LINK_CONTRACT_ADDRESS).transfer(B, 10000);
        testDepositTCollateral();

        uint128 requestAmount = 10000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days; // 1 year later

        protocolFacet.createLendingRequest(
            requestAmount,
            interestRate,
            returnDate,
            LINK_CONTRACT_ADDRESS
        );
        switchSigner(B);

        // daiContract.approve(address(protocol), requestAmount);
        vm.expectRevert(
            abi.encodeWithSelector(Protocol__InsufficientAllowance.selector)
        );

        protocolFacet.serviceRequest(1, LINK_CONTRACT_ADDRESS);
    }

    function testUserCanCreateListingAds() public {

        switchSigner(owner);
        uint128 requestAmount = 10000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days;

        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );
        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );
        // Verify that the request is correctly added  
        Order[] memory orders = protocolFacet.getAllListedOrders();
        assertEq(orders.length, 2);
        assertEq(orders[0].amount, requestAmount);
    }


    function testUserCanAcceptListedAds() public{
        switchSigner(owner);

        IERC20(USDT_CONTRACT_ADDRESS).transfer(B, 1000000);

        uint128 requestAmount = 1000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days;

        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );
        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );

        switchSigner(B);
        IERC20(USDT_CONTRACT_ADDRESS).approve(address(protocolFacet), 10000000);
        protocolFacet.depositCollateral(USDT_CONTRACT_ADDRESS, 100000);


        protocolFacet.acceptListedAds(1);
        assertEq(IERC20(DIA_CONTRACT_ADDRESS).balanceOf(B), 1000);
    }

    function testUserCannotAcceptListedAdsWithoutDepositingColateral() public{
        switchSigner(owner);

        IERC20(USDT_CONTRACT_ADDRESS).transfer(B, 1000000);

        uint128 requestAmount = 1000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days;

        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );
        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );

        switchSigner(B);
     
         vm.expectRevert(
            abi.encodeWithSelector(Protocol__InsufficientCollateral.selector)
        );
        protocolFacet.acceptListedAds(1);
    }

    function testUserCanWithdrawnDepositedAdsToken() public {
        switchSigner(owner);

        uint128 requestAmount = 10000;
        uint8 interestRate = 5;
        uint256 returnDate = block.timestamp + 365 days;

        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );
        protocolFacet.createListingAds(
            requestAmount,
            interestRate,
            returnDate,
            DIA_CONTRACT_ADDRESS
        );

        uint256 _AfterDepositTokenAds =  IERC20(DIA_CONTRACT_ADDRESS).balanceOf(owner);


        protocolFacet.withdrawnDepositedAdsToken(1);

        uint256 _AfterWithdrawnTokenAds =  IERC20(DIA_CONTRACT_ADDRESS).balanceOf(owner);

        assertEq(_AfterWithdrawnTokenAds, _AfterDepositTokenAds + requestAmount);

    }

    


       


    






    function transferTokenToOwner() public {
        switchSigner(USDTHolders);
        IERC20(USDT_CONTRACT_ADDRESS).transfer(owner, 500000000000);
        switchSigner(DAIHolders);
        IERC20(DIA_CONTRACT_ADDRESS).transfer(owner, 500000000000);
        switchSigner(WETHHolders);
        IERC20(WETH_CONTRACT_ADDRESS).transfer(owner, 500000000000);
        switchSigner(LINKHolders);
        IERC20(LINK_CONTRACT_ADDRESS).transfer(owner, 500000000000);
    }



    function depositCollateral(
        address user,
        address token,
        uint128 amount
    ) public {
        switchSigner(user);
        IERC20(token).approve(address(protocolFacet), type(uint).max);
        protocolFacet.depositCollateral(token, amount);
    }







    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }








    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }

    }






    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
