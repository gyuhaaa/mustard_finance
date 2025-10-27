pragma solidity 0.8.16;

contract MockRouter {
	mapping(address => mapping(address => address)) pairs;

	constructor() {}

	function addPair(address tokenA, address tokenB, address pair) public {
		// Audit: tokenA, tokenB, pair 주소가 영주소인 경우 예외처리 필요
		require(tokenA != address(0), "MockRouter: tokenA cannot be zero address");
		require(tokenB != address(0), "MockRouter: tokenB cannot be zero address");
		require(pair != address(0), "MockRouter: pair cannot be zero address");
		// Audit: tokenA, tokenB가 같은 주소인 경우 예외처리 필요
		require(tokenA != tokenB, "MockRouter: tokenA and tokenB must be different");
		pairs[tokenA][tokenB] = pair;
	}

	function getPair(address tokenA, address tokenB) public view returns(address) { 
		// Audit: tokenA, tokenB 주소가 영주소인 경우 예외처리 필요
		require(tokenA != address(0), "MockRouter: tokenA cannot be zero address");
		require(tokenB != address(0), "MockRouter: tokenB cannot be zero address");
		return pairs[tokenA][tokenB];
	}
}