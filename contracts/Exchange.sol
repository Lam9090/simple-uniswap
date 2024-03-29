// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20{
    address public tokenAddress;
    constructor(address token) ERC20('Liquidity Provider Tokens','LPT') {
        tokenAddress = token;
    }

    function getReserve() public view returns (uint){
        return ERC20(tokenAddress).balanceOf(address(this));
    }

    /// @dev allow user to add liquidity to the exchange
    function addLiquidity(uint tokenAmount)public payable returns (uint lrTokenAmount){
        uint lrTokenToMint;
        uint ethReserveBalance = address(this).balance;
        uint tokenReserveBalance = getReserve();
        ERC20 token = ERC20(tokenAddress);

        // initial set the initial liquidity
        if (tokenReserveBalance == 0) {
            // transfer the token of given amount to the pool from the msg.sender (the one who want to add liquidity)
            token.transferFrom(msg.sender, address(this), tokenAmount);
            lrTokenToMint = msg.value;
            _mint(msg.sender, lrTokenToMint);
            return lrTokenToMint;
        }
        uint prevEthReserveBalance = ethReserveBalance - msg.value;
         
        // suppose the tokenReserve was x and the eth was y, the ratio is x/y;
        // the second one should follow this ratio, furmula is x / y = baseTokenAmount / msg.value;
        // the give token amount should reach the base token amount
        uint baseTokenAmount =  msg.value * tokenReserveBalance / prevEthReserveBalance;

        require(tokenAmount >= baseTokenAmount,'Insufficient token amount provided');

        token.transferFrom(msg.sender, address(this), baseTokenAmount);

        // totalSupply() returns the total amount of lrToken;
        lrTokenToMint = msg.value * totalSupply() / prevEthReserveBalance;
        _mint(msg.sender,lrTokenToMint);

        return lrTokenToMint;
    }

    event removeLiquidityLog(string msg, bool success);
    /// @dev removeLiquidity allows users to remove liquidity from the exchange
    function removeLiquidity(uint lpTokenAmount) public returns (uint ethToReturn, uint tokenToReturn){
        uint availableLpAmount = balanceOf(msg.sender);
        require(lpTokenAmount <= availableLpAmount,'Insufficient token amount provided');

        uint ethReserve = address(this).balance;
        uint tokenReserve = getReserve();
        uint totalLpToken = totalSupply();

        ethToReturn = ethReserve * lpTokenAmount / totalLpToken;

        tokenToReturn = tokenReserve * lpTokenAmount / totalLpToken;

        _burn(msg.sender, lpTokenAmount);
        payable(msg.sender).transfer(ethToReturn);
        ERC20(tokenAddress).transfer(msg.sender, tokenToReturn);
        return (ethToReturn,tokenToReturn);
    }

    uint public taxRateNumerator = 1;
    uint public taxRateDenominator = 100;

    function getTaxRate() public view returns (uint,uint){
        return (taxRateNumerator,taxRateDenominator);
    }

    function setTax(uint _taxRateNumerator,uint _taxRateDenominator) public returns (uint,uint){
        require(_taxRateNumerator > 0 && _taxRateDenominator > 0, 'Tax Rate Must be greate than 0');
        require(_taxRateNumerator < _taxRateDenominator, 'Invalid Argument: TaxRateDenominator must be greate than TaxRateNumerator');
        taxRateNumerator = _taxRateNumerator;
        taxRateDenominator = _taxRateDenominator ;
        return (_taxRateNumerator,_taxRateDenominator);
    }

    function chargeTax (uint inputAmount)public view returns (uint) {
        return inputAmount * (1 - taxRateNumerator/taxRateDenominator);
    }

    /// @dev getOutputAmountFromSwap calculates the amount of output tokens to be received based on xy = (x + dx)(y - dy)
    /// this always calculate the dy as the outputAmount, thus dy = y*dx / (x+dx) 
    function getOutputAmount(uint inputAmount ,uint inputReserve,uint outputReserve) public view returns (uint){
        // x*y must be always greate than 0
        require(inputReserve > 0 && outputReserve > 0, 'Reserves must be greater than 0');

        uint inputAmountWithFee = chargeTax(inputAmount);

        uint numerator = outputReserve * inputAmountWithFee;

        uint denominator = inputReserve + inputAmountWithFee;

        return numerator / denominator;
    }

    /// @dev ethToTokenSwap allow user to exchange eth for tokens
    function ethToTokenSwap (uint minTokenToReceive)public payable {
        uint ethReserve = address(this).balance;
        uint tokenReserve = getReserve();
        uint tokenToReceive = getOutputAmount((msg.value), ethReserve - msg.value, tokenReserve);

        require(tokenToReceive >= minTokenToReceive, 'Insufficient tokens to be receive expected');

        ERC20(tokenAddress).transfer(msg.sender, tokenToReceive);

    }

    /// tokenToEthSwap allows users to swap tokens for ETH
    function tokenToEthSwap(uint tokenToSwap, uint minEthToReceive)public {
        uint ethReserve = address(this).balance;
        uint tokenReserve = getReserve();

        uint ethToReceive = getOutputAmount(tokenToSwap, tokenReserve, ethReserve);

        require(ethToReceive >= minEthToReceive, 'Insufficient eth to be receive expected');

        ERC20(tokenAddress).transferFrom(msg.sender, address(this), tokenToSwap);

        payable(msg.sender).transfer(ethToReceive);
    }
}